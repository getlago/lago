import { gql } from '@apollo/client'
import InputAdornment from '@mui/material/InputAdornment'
import { useFormik } from 'formik'
import { DateTime } from 'luxon'
import { useCallback, useEffect, useMemo, useRef } from 'react'
import { generatePath, useParams, useSearchParams } from 'react-router-dom'
import { date, object, string } from 'yup'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { Status } from '~/components/designSystem/Status'
import { Table } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { WarningDialog, WarningDialogRef } from '~/components/designSystem/WarningDialog'
import { AmountInputField, ComboBox, DatePickerField, TextInputField } from '~/components/form'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { addToast } from '~/core/apolloClient'
import { paymentStatusMapping } from '~/core/constants/statusInvoiceMapping'
import { getCurrencySymbol, intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { PAYMENT_DETAILS_ROUTE, PAYMENTS_ROUTE, useNavigate } from '~/core/router'
import { deserializeAmount, serializeAmount } from '~/core/serializers/serializeAmount'
import { intlFormatDateTime } from '~/core/timezone'
import {
  CreatePaymentInput,
  CurrencyEnum,
  InvoiceStatusTypeEnum,
  InvoiceTypeEnum,
  LagoApiError,
  useCreatePaymentMutation,
  useGetPayableInvoiceQuery,
  useGetPayableInvoicesQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useLocationHistory } from '~/hooks/core/useLocationHistory'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { FormLoadingSkeleton } from '~/styles/mainObjectsForm'
import { tw } from '~/styles/utils'

gql`
  query GetPayableInvoices($customerExternalId: String, $status: [InvoiceStatusTypeEnum!]) {
    invoices(positiveDueAmount: true, customerExternalId: $customerExternalId, status: $status) {
      collection {
        id
        number
        currency
      }
    }
  }

  query GetPayableInvoice($id: ID!) {
    invoice(id: $id) {
      id
      number
      paymentStatus
      status
      totalDueAmountCents
      issuingDate
      currency
      invoiceType
    }
  }

  mutation CreatePayment($input: CreatePaymentInput!) {
    createPayment(input: $input) {
      id
    }
  }
`

const today = DateTime.now().toISO()

const CreatePayment = () => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const { goBack } = useLocationHistory()
  const params = useParams<{ invoiceId?: string }>()
  const [searchParams] = useSearchParams()

  const warningDirtyAttributesDialogRef = useRef<WarningDialogRef>(null)
  const { timezone } = useOrganizationInfos()

  const formikProps = useFormik<CreatePaymentInput>({
    initialValues: {
      invoiceId: params.invoiceId ?? '',
      amountCents: '',
      reference: '',
      createdAt: today,
    },
    validationSchema: object().shape({
      invoiceId: string().required(''),
      amountCents: string()
        .required('')
        .test((value) => maxAmount(value)),
      reference: string().max(40).required(''),
      createdAt: date().required(''),
    }),
    enableReinitialize: true,
    validateOnMount: true,
    onSubmit: async (values) => {
      await createPayment({
        variables: {
          input: {
            ...values,
            amountCents: serializeAmount(values.amountCents, currency),
          },
        },
      })
    },
  })

  const { data: payableInvoices, loading: payableInvoicesLoading } = useGetPayableInvoicesQuery({
    variables: {
      customerExternalId: searchParams.get('externalId'),
      status: [InvoiceStatusTypeEnum.Finalized],
    },
  })

  const { data, loading: invoiceLoading } = useGetPayableInvoiceQuery({
    variables: { id: formikProps.values.invoiceId },
    skip: !formikProps.values.invoiceId,
  })

  const invoice = data?.invoice

  useEffect(() => {
    if (invoice && invoice.invoiceType === InvoiceTypeEnum.Credit) {
      formikProps.setFieldValue(
        'amountCents',
        deserializeAmount(invoice.totalDueAmountCents, invoice.currency ?? CurrencyEnum.Usd),
      )
    }

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [invoice])

  const currency = invoice?.currency ?? CurrencyEnum.Usd

  const [createPayment, { error: createError }] = useCreatePaymentMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    onCompleted({ createPayment: createdPayment }) {
      if (!!createdPayment) {
        addToast({
          severity: 'success',
          translateKey: 'text_173755495088700ivx6izvjv',
        })
        navigate(generatePath(PAYMENT_DETAILS_ROUTE, { paymentId: createdPayment?.id }))
      }
    },
  })

  useEffect(() => {
    if (createError) {
      const errorCode = createError.graphQLErrors[0].extensions?.details

      formikProps.setErrors({
        ...formikProps.errors,
        ...(errorCode ?? {}),
      })
    }

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [createError])

  const maxAmount = useCallback(
    (value: string) => {
      const amount = Number(value)

      const isExceeding =
        amount > 0 && amount <= deserializeAmount(invoice?.totalDueAmountCents ?? 0, currency)

      if (!isExceeding) {
        return false
      }
      return true
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [invoice],
  )

  const remainingAmount = useMemo(() => {
    const totalAmount = deserializeAmount(invoice?.totalDueAmountCents ?? 0, currency)
    const amount = Number(formikProps.values.amountCents)

    return totalAmount - amount
  }, [formikProps.values.amountCents, invoice, currency])

  const onLeave = () => {
    goBack(generatePath(PAYMENTS_ROUTE))
  }

  const dateTime = intlFormatDateTime(formikProps.values.createdAt, {
    timezone,
  })

  return (
    <>
      <CenteredPage.Wrapper>
        <CenteredPage.Header>
          <Typography variant="bodyHl" color="textSecondary" noWrap>
            {translate('text_1737473550277wkq2gsbaiab')}
          </Typography>
          <Button
            variant="quaternary"
            icon="close"
            onClick={() =>
              formikProps.dirty ? warningDirtyAttributesDialogRef.current?.openDialog() : onLeave()
            }
          />
        </CenteredPage.Header>

        <CenteredPage.Container>
          {invoiceLoading && <FormLoadingSkeleton id="create-payment-request" />}
          {!invoiceLoading && (
            <>
              <div className="not-last-child:mb-1">
                <Typography variant="headline" color="textSecondary">
                  {translate('text_1737471851634wpeojigr27w')}
                </Typography>
                <Typography variant="body">{translate('text_1737472944878vyh7qulgo77')}</Typography>
              </div>

              <div className="flex flex-col gap-12">
                <section className={tw('not-last-child:mb-6', invoice ? 'pb-0' : 'pb-12 shadow-b')}>
                  <div className="not-last-child:mb-2">
                    <Typography variant="subhead1">
                      {translate('text_17374729448780zbfa44h1s3')}
                    </Typography>
                    <Typography variant="caption">
                      {translate('text_1737472944878ggfenh0ifpi')}
                    </Typography>
                  </div>
                  <div className="flex flex-col gap-6 *:flex-1">
                    <ComboBox
                      name="invoiceId"
                      label={translate('text_64188b3d9735d5007d71226c')}
                      data={(payableInvoices?.invoices.collection ?? []).map(({ id, number }) => ({
                        value: id,
                        label: number,
                      }))}
                      onChange={(value) => formikProps.setFieldValue('invoiceId', value)}
                      placeholder={translate('text_17374729448787bzb5yjrbgt')}
                      emptyText={translate('text_6682c52081acea9052074686')}
                      value={formikProps.values.invoiceId}
                      loading={payableInvoicesLoading}
                      disabled={!!params.invoiceId}
                      disableClearable={!!params.invoiceId}
                    />

                    {invoice && (
                      <Table
                        name="invoice"
                        data={invoice ? [invoice] : []}
                        containerSize={0}
                        columns={[
                          {
                            key: 'paymentStatus',
                            title: translate('text_6419c64eace749372fc72b40'),
                            content: ({ paymentStatus, status }) => {
                              return <Status {...paymentStatusMapping({ paymentStatus, status })} />
                            },
                          },
                          {
                            key: 'number',
                            title: translate('text_64188b3d9735d5007d71226c'),
                            maxSpace: true,
                            content: ({ number }) => number,
                          },
                          {
                            key: 'totalDueAmountCents',
                            title: translate('text_17374735502775afvcm9pqxk'),
                            textAlign: 'right',
                            content: ({ totalDueAmountCents }) => (
                              <Typography variant="bodyHl" color="textSecondary">
                                {intlFormatNumber(
                                  deserializeAmount(totalDueAmountCents, currency),
                                  {
                                    currency,
                                  },
                                )}
                              </Typography>
                            ),
                          },
                          {
                            key: 'issuingDate',
                            title: translate('text_6419c64eace749372fc72b39'),
                            content: ({ issuingDate }) =>
                              intlFormatDateTime(issuingDate, { timezone }).date,
                          },
                        ]}
                      />
                    )}
                  </div>
                </section>

                <section className="not-last-child:mb-6">
                  <div className="not-last-child:mb-2">
                    <Typography variant="subhead1">
                      {translate('text_1737472944878h2ejm3kxd8h')}
                    </Typography>
                    <Typography variant="caption">
                      {translate('text_173747294487841dlz5wqd9p')}
                    </Typography>
                  </div>
                  <div className="flex flex-col gap-6 *:flex-1">
                    <div>
                      <DatePickerField
                        name="createdAt"
                        label={translate('text_1737472944878qfpm9xbrrdn')}
                        formikProps={formikProps}
                      />
                      <Typography variant="caption">
                        {translate('text_1737473550277yfvnl60zpiz', {
                          date: dateTime.date,
                          hour: dateTime.time,
                        })}
                      </Typography>
                    </div>

                    <TextInputField
                      name="reference"
                      formikProps={formikProps}
                      error={!!formikProps.errors.reference}
                      label={translate('text_1737472944878njss1jk5yik')}
                      helperText={translate('text_1737472944878ksy1jz0b4m9')}
                      placeholder={translate('text_1737473550277onyc98womp2')}
                    />

                    <AmountInputField
                      name="amountCents"
                      formikProps={formikProps}
                      error={
                        !!formikProps.errors.amountCents && !!formikProps.values.invoiceId
                          ? translate('text_6374e868262bab8719eac11f', {
                              max: intlFormatNumber(
                                deserializeAmount(
                                  invoice?.totalDueAmountCents,
                                  invoice?.currency ?? CurrencyEnum.Usd,
                                ),
                                {
                                  currency,
                                },
                              ),
                            })
                          : ''
                      }
                      label={translate('text_1737472944878ee19ufaaklg')}
                      currency={currency}
                      beforeChangeFormatter={['positiveNumber']}
                      placeholder="0.00"
                      disabled={invoice?.invoiceType === InvoiceTypeEnum.Credit}
                      InputProps={{
                        startAdornment: currency && (
                          <InputAdornment position="start">
                            {getCurrencySymbol(currency)}
                          </InputAdornment>
                        ),
                      }}
                      helperText={
                        invoice &&
                        translate('text_1737473550277cncnhv0x6cm', {
                          amount: intlFormatNumber(remainingAmount, {
                            currency,
                          }),
                        })
                      }
                    />

                    <Alert type="warning">
                      <Typography color="textSecondary">
                        {translate('text_17374735502775voeeu0q7b7')}
                      </Typography>
                    </Alert>
                  </div>
                </section>
              </div>
            </>
          )}
        </CenteredPage.Container>

        <CenteredPage.StickyFooter>
          <Button
            variant="quaternary"
            onClick={() =>
              formikProps.dirty ? warningDirtyAttributesDialogRef.current?.openDialog() : onLeave()
            }
          >
            {translate('text_6411e6b530cb47007488b027')}
          </Button>
          <Button
            variant="primary"
            disabled={!formikProps.isValid || !formikProps.dirty}
            onClick={formikProps.submitForm}
          >
            {translate('text_1737473550277wkq2gsbaiab')}
          </Button>
        </CenteredPage.StickyFooter>
      </CenteredPage.Wrapper>

      <WarningDialog
        ref={warningDirtyAttributesDialogRef}
        title={translate('text_6244277fe0975300fe3fb940')}
        description={translate('text_6244277fe0975300fe3fb946')}
        continueText={translate('text_6244277fe0975300fe3fb94c')}
        onContinue={onLeave}
      />
    </>
  )
}

export default CreatePayment
