import { useFormik } from 'formik'
import { Icon } from 'lago-design-system'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { generatePath, useParams } from 'react-router-dom'
import { array, object, Schema, string } from 'yup'

import { CreditNoteEstimationLine } from '~/components/creditNote/CreditNoteEstimationLine'
import { CreditNoteFormAllocation } from '~/components/creditNote/CreditNoteFormAllocation'
import { CreditNoteFormCalculation } from '~/components/creditNote/CreditNoteFormCalculation'
import { CreditNoteItemsForm } from '~/components/creditNote/CreditNoteItemsForm'
import { CreditNoteForm, CreditTypeEnum } from '~/components/creditNote/types'
import { useCreditNoteFormCalculation } from '~/components/creditNote/useCreditNoteFormCalculation'
import {
  buildInitialPayBack,
  canCreateCreditNote,
  creditNoteFormCalculationCalculation,
  creditNoteFormHasAtLeastOneFeeChecked,
  hasOffsettableAmount,
} from '~/components/creditNote/utils'
import { Alert } from '~/components/designSystem/Alert'
import { Avatar } from '~/components/designSystem/Avatar'
import { Button } from '~/components/designSystem/Button'
import { Card } from '~/components/designSystem/Card'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { WarningDialog, WarningDialogRef } from '~/components/designSystem/WarningDialog'
import { ComboBoxField, TextInputField } from '~/components/form'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { hasDefinedGQLError } from '~/core/apolloClient'
import { CustomerInvoiceDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { CUSTOMER_INVOICE_DETAILS_ROUTE, useNavigate } from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import {
  generateAddOnFeesSchema,
  generateCreditFeesSchema,
  generateFeesSchema,
} from '~/formValidation/feesSchema'
import { metadataSchema } from '~/formValidation/metadataSchema'
import {
  CreditNoteReasonEnum,
  CurrencyEnum,
  InvoiceTypeEnum,
  LagoApiError,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { PageHeader } from '~/styles'

import { useCreateCreditNote } from './common/useCreateCreditNote'
import MetadataFormCard from './metadataForm/MetadataFormCard'

export const SUBMIT_BUTTON_TEST_ID = 'submit-credit-note-button'
export const REASON_COMBOBOX_TEST_ID = 'reason-combobox'
export const DESCRIPTION_INPUT_TEST_ID = 'description-input'
export const PREPAID_CREDITS_REFUND_ALERT_TEST_ID = 'prepaid-credits-refund-alert'
export const CLOSE_BUTTON_TEST_ID = 'close-credit-note-button'

export const CREDIT_NOTE_REASONS: { reason: CreditNoteReasonEnum; label: string }[] = [
  {
    reason: CreditNoteReasonEnum?.DuplicatedCharge,
    label: 'text_636d85ee6459e3fc0a859123',
  },
  {
    reason: CreditNoteReasonEnum?.FraudulentCharge,
    label: 'text_636d864c7046be9069662e9d',
  },
  {
    reason: CreditNoteReasonEnum?.OrderCancellation,
    label: 'text_636d86390ce8d6d7ed8ce937',
  },
  {
    reason: CreditNoteReasonEnum?.OrderChange,
    label: 'text_636d8642904c9f56a8b2d834',
  },
  {
    reason: CreditNoteReasonEnum?.Other,
    label: 'text_636d86cd9fd41b93c35bf1c7',
  },
  {
    reason: CreditNoteReasonEnum?.ProductUnsatisfactory,
    label: 'text_636d86201507276b7421a981',
  },
]

const CreateCreditNote = () => {
  const navigate = useNavigate()
  const { translate } = useInternationalization()
  const warningDialogRef = useRef<WarningDialogRef>(null)
  const { customerId, invoiceId } = useParams()
  const {
    loading,
    invoice,
    feesPerInvoice,
    feeForAddOn,
    feeForCredit,
    hasCreditableOrRefundableAmount,
    onCreate,
  } = useCreateCreditNote()
  const currency = invoice?.currency || CurrencyEnum.Usd

  const initialPayBack = buildInitialPayBack(invoice)

  const addOnFeesValidation = useMemo(
    () => generateAddOnFeesSchema(feeForAddOn || [], currency),
    [feeForAddOn, currency],
  )

  const feesValidation = useMemo(
    () => generateFeesSchema(feesPerInvoice || {}, currency),
    [feesPerInvoice, currency],
  )

  const creditFeeValidation = useMemo(
    () => generateCreditFeesSchema(feeForCredit || [], currency),
    [feeForCredit, currency],
  )

  const [payBackValidation, setPayBackValidation] = useState<Schema>(array())

  const formikProps = useFormik<Partial<CreditNoteForm>>({
    validateOnMount: true,
    enableReinitialize: true,
    initialValues: {
      description: undefined,
      reason: undefined,
      fees: feesPerInvoice,
      addOnFee: feeForAddOn,
      creditFee: feeForCredit,
      payBack: initialPayBack,
      creditAmount: undefined,
      refundAmount: undefined,
      metadata: [],
    },
    validationSchema: object().shape({
      reason: string().required(''),
      fees: feesValidation,
      addOnFee: addOnFeesValidation,
      creditFee: creditFeeValidation,
      payBack: payBackValidation,
      metadata: metadataSchema({
        keyMaxLength: 40,
        valueMaxLength: 255,
      }),
    }),
    onSubmit: async (values, formikBag) => {
      const formattedValues = {
        ...values,
        metadata: (values.metadata || []).map((metadata) => ({
          key: metadata.key,
          value: metadata.value,
        })),
      } as CreditNoteForm

      const answer = await onCreate(formattedValues)

      if (hasDefinedGQLError('DoesNotMatchItemAmounts', answer?.errors)) {
        formikBag.setErrors({
          // @ts-expect-error - Formik doesn't know it here but we have 2 values in the array if we get this error
          payBack: [
            { value: LagoApiError.DoesNotMatchItemAmounts },
            { value: LagoApiError.DoesNotMatchItemAmounts },
          ],
        })
      }
    },
  })

  const hasError = !!formikProps.errors.fees || !!formikProps.errors.addOnFee

  const { feeForEstimate } = useMemo(
    () =>
      creditNoteFormCalculationCalculation({
        currency,
        hasError,
        fees: formikProps.values.fees,
        addonFees: formikProps.values.addOnFee,
      }),
    [currency, formikProps.values.addOnFee, formikProps.values.fees, hasError],
  )

  const creditNoteCalculation = useCreditNoteFormCalculation({
    invoice,
    formikProps,
    feeForEstimate,
    setPayBackValidation,
  })

  const isPrepaidCreditsInvoice = invoice?.invoiceType === InvoiceTypeEnum.Credit

  const creditFeeValue = formikProps.values.creditFee?.[0]?.value

  const hasOffsettable = hasOffsettableAmount(invoice)

  useEffect(() => {
    if (isPrepaidCreditsInvoice && creditFeeValue) {
      if (hasCreditableOrRefundableAmount) {
        formikProps.setFieldValue('payBack', [
          {
            type: CreditTypeEnum.refund,
            value: creditFeeValue,
          },
        ])
      } else if (hasOffsettable) {
        formikProps.setFieldValue('payBack', [
          {
            type: CreditTypeEnum.offset,
            value: creditFeeValue,
          },
        ])
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isPrepaidCreditsInvoice, creditFeeValue, hasCreditableOrRefundableAmount, hasOffsettable])

  // Reset payBack values, errors, and touched state when fee items change (for non-prepaid credits invoices)
  const isInitialFeesMount = useRef(true)
  const resetPayBackAllocation = useCallback(() => {
    // Reset payBack values to 0
    const currentPayBack = formikProps.values.payBack || []
    const resetPayBack = currentPayBack.map((item) => ({
      ...item,
      value: undefined,
    }))

    formikProps.setFieldValue('payBack', resetPayBack)

    // Clear payBack errors (payBackErrors is a custom error field added dynamically)
    const errors = formikProps.errors as Record<string, unknown>

    if (errors.payBack || errors.payBackErrors) {
      const cleanedErrors = { ...errors, payBack: undefined, payBackErrors: undefined }

      formikProps.setErrors(cleanedErrors as typeof formikProps.errors)
    }

    // Reset touched state for payBack fields
    const currentTouched = formikProps.touched as Record<string, unknown>

    if (currentTouched.payBack) {
      formikProps.setTouched({
        ...currentTouched,
        payBack: undefined,
      } as typeof formikProps.touched)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [formikProps.values.payBack])

  useEffect(() => {
    // Skip reset on initial mount
    if (isInitialFeesMount.current) {
      isInitialFeesMount.current = false
      return
    }

    // Only reset for non-prepaid credits invoices
    if (!isPrepaidCreditsInvoice) {
      resetPayBackAllocation()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [formikProps.values.fees, formikProps.values.addOnFee])

  const formHasAtLeastOneFeeChecked: boolean = useMemo(() => {
    return creditNoteFormHasAtLeastOneFeeChecked(formikProps.values)
  }, [formikProps.values])

  return (
    <div>
      <PageHeader.Wrapper>
        {loading ? (
          <div>
            <Skeleton variant="text" className="w-30" />
          </div>
        ) : (
          <Typography variant="bodyHl" color="textSecondary" noWrap>
            {translate('text_636bedf292786b19d3398eb9', {
              invoiceNumber: invoice?.number,
            })}
          </Typography>
        )}
        <Button
          variant="quaternary"
          icon="close"
          data-test={CLOSE_BUTTON_TEST_ID}
          onClick={() =>
            formikProps.dirty
              ? warningDialogRef.current?.openDialog()
              : navigate(
                  generatePath(CUSTOMER_INVOICE_DETAILS_ROUTE, {
                    customerId: customerId as string,
                    invoiceId: invoiceId as string,
                    tab: CustomerInvoiceDetailsTabsOptionsEnum.overview,
                  }),
                )
          }
        />
      </PageHeader.Wrapper>
      <CenteredPage.Container>
        {loading ? (
          <>
            <Skeleton variant="text" className="mb-5 w-70" />
            <Skeleton variant="text" className="mb-10 w-120" />
            <Card className="flex flex-row items-center gap-3 p-4">
              <Skeleton variant="connectorAvatar" size="medium" />
              <Skeleton variant="text" className="w-40" />
            </Card>
            <Card>
              <Skeleton variant="text" className="w-104" />
              <Skeleton variant="text" className="w-164" />
              <Skeleton variant="text" className="w-64" />
            </Card>
            <div className="mb-20 px-8">
              <Button size="large" disabled fullWidth>
                {translate('text_636bdef6565341dcb9cfb127')}
              </Button>
            </div>
          </>
        ) : (
          <>
            <CenteredPage.PageTitle
              title={translate('text_636bdef6565341dcb9cfb127')}
              description={translate('text_636bedf292786b19d3398ec6')}
            />
            <div className="flex flex-col gap-12 border-b border-grey-300 pb-12">
              <div className="flex flex-col">
                <Typography className="mb-2" variant="subhead1" color="grey700">
                  {translate('text_17374729448780zbfa44h1s3')}
                </Typography>
                <Typography variant="caption" color="grey600">
                  {translate('text_1766074535186op0u7tt7ses')}
                </Typography>

                <div className="mt-3 overflow-hidden rounded-xl border border-grey-300">
                  <div className="flex items-center justify-between p-4">
                    <div className="flex items-center gap-3">
                      <Avatar size="big" variant="connector">
                        <Icon name="document" />
                      </Avatar>
                      <div>
                        <Typography variant="caption" color="grey600">
                          {translate('text_634687079be251fdb43833fb')}
                        </Typography>
                        <Typography variant="bodyHl" color="grey700">
                          {invoice?.number}
                        </Typography>
                      </div>
                    </div>
                    <div className="text-right">
                      <Typography variant="caption" color="grey600">
                        {translate('text_65a6b4e2cb38d9b70ec53d83')}
                      </Typography>
                      <Typography variant="bodyHl" color="grey700">
                        {intlFormatNumber(deserializeAmount(invoice?.totalAmountCents, currency), {
                          currency,
                        })}
                      </Typography>
                    </div>
                  </div>

                  <div className="grid grid-cols-3 gap-4 border-t border-grey-300 bg-grey-100 p-4">
                    <div>
                      <Typography variant="caption" color="grey600">
                        {translate('text_1766074535187gdkj5p0iln0')}
                      </Typography>
                      <Typography variant="body" color="grey700">
                        {intlFormatNumber(
                          deserializeAmount(invoice?.totalPaidAmountCents || 0, currency),
                          { currency },
                        )}
                      </Typography>
                    </div>
                    <div>
                      <Typography variant="caption" color="grey600">
                        {translate('text_17374735502775afvcm9pqxk')}
                      </Typography>
                      <Typography variant="body" color="grey700">
                        {intlFormatNumber(
                          deserializeAmount(invoice?.totalDueAmountCents || 0, currency),
                          { currency },
                        )}
                      </Typography>
                    </div>
                    <div>
                      <Typography variant="caption" color="grey600">
                        {translate('text_1766074535187nro7qatdzyh')}
                      </Typography>
                      <Typography variant="body" color="grey700">
                        {intlFormatNumber(
                          deserializeAmount(invoice?.refundableAmountCents || 0, currency),
                          { currency },
                        )}
                      </Typography>
                    </div>
                  </div>
                </div>
              </div>

              <div className="flex flex-col gap-6">
                <Typography variant="subhead1">
                  {translate('text_636bedf292786b19d3398ece')}
                </Typography>
                <ComboBoxField
                  name="reason"
                  formikProps={formikProps}
                  label={translate('text_636bedf292786b19d3398ed0')}
                  placeholder={translate('text_636bedf292786b19d3398ed2')}
                  data={CREDIT_NOTE_REASONS.map((reason) => ({
                    value: reason.reason,
                    label: translate(reason.label),
                  }))}
                  data-test={REASON_COMBOBOX_TEST_ID}
                />
                <TextInputField
                  name="description"
                  formikProps={formikProps}
                  label={translate('text_636bedf292786b19d3398ed4')}
                  placeholder={translate('text_636bedf292786b19d3398ed6')}
                  rows={3}
                  multiline
                  data-test={DESCRIPTION_INPUT_TEST_ID}
                />
              </div>
            </div>

            <div className="flex flex-col gap-6 border-b border-grey-300 pb-12">
              <div>
                <Typography className="mb-2" variant="subhead1" color="grey700">
                  {translate('text_636bedf292786b19d3398ed8')}
                </Typography>
                <Typography variant="caption" color="grey600">
                  {translate('text_1766133873554m5a3a9c8x2f')}
                </Typography>
              </div>

              <div>
                <Typography variant="caption">
                  {translate('text_636bedf292786b19d3398eda')}
                </Typography>
                <Typography variant="bodyHl" color="grey700">
                  {translate('text_636bedf292786b19d3398edc', {
                    invoiceNumber: invoice?.number,
                    subtotal: intlFormatNumber(
                      deserializeAmount(invoice?.subTotalIncludingTaxesAmountCents || 0, currency),
                      {
                        currency,
                      },
                    ),
                  })}
                </Typography>
              </div>

              <CreditNoteItemsForm
                isPrepaidCreditsInvoice={isPrepaidCreditsInvoice}
                formikProps={formikProps}
                feeForCredit={feeForCredit}
                feeForAddOn={feeForAddOn}
                feesPerInvoice={feesPerInvoice}
                currency={currency}
              />

              {isPrepaidCreditsInvoice ? (
                <>
                  <div className="ml-auto w-full max-w-100">
                    <CreditNoteEstimationLine
                      label={
                        hasCreditableOrRefundableAmount
                          ? translate('text_17270794543889mcmuhfq70p')
                          : translate('text_1767883339943r32jn2ioyeu')
                      }
                      value={intlFormatNumber(
                        Number(formikProps.values.creditFee?.[0]?.value || 0),
                        {
                          currency,
                        },
                      )}
                    />
                  </div>

                  {hasCreditableOrRefundableAmount && (
                    <Alert
                      className="mt-6"
                      type="info"
                      data-test={PREPAID_CREDITS_REFUND_ALERT_TEST_ID}
                    >
                      {translate('text_1729084495407pcn1mei0hyd')}
                    </Alert>
                  )}
                </>
              ) : (
                <CreditNoteFormCalculation
                  hasError={hasError}
                  currency={creditNoteCalculation.currency}
                  estimationLoading={creditNoteCalculation.estimationLoading}
                  hasCouponLine={creditNoteCalculation.hasCouponLine}
                  proRatedCouponAmount={creditNoteCalculation.proRatedCouponAmount}
                  totalExcludedTax={creditNoteCalculation.totalExcludedTax}
                  taxes={creditNoteCalculation.taxes}
                  totalTaxIncluded={creditNoteCalculation.totalTaxIncluded}
                  canOnlyCredit={creditNoteCalculation.canOnlyCredit}
                />
              )}
            </div>

            {!isPrepaidCreditsInvoice && canCreateCreditNote(invoice) && (
              <div className="flex flex-col gap-6 border-b border-grey-300 pb-12">
                <CreditNoteFormAllocation
                  formikProps={formikProps}
                  currency={creditNoteCalculation.currency}
                  maxCreditableAmount={creditNoteCalculation.maxCreditableAmount}
                  maxRefundableAmount={creditNoteCalculation.maxRefundableAmount}
                  maxOffsettableAmount={creditNoteCalculation.maxOffsettableAmount}
                  totalTaxIncluded={creditNoteCalculation.totalTaxIncluded}
                  estimationLoading={creditNoteCalculation.estimationLoading}
                />
              </div>
            )}

            <div className="flex flex-col">
              <MetadataFormCard formikProps={formikProps} />
            </div>
          </>
        )}
      </CenteredPage.Container>

      <CenteredPage.StickyFooter>
        <div className="flex h-full items-center justify-end gap-3">
          <Button
            variant="quaternary"
            onClick={() =>
              navigate(
                generatePath(CUSTOMER_INVOICE_DETAILS_ROUTE, {
                  customerId: customerId ?? '',
                  invoiceId: invoiceId ?? '',
                  tab: CustomerInvoiceDetailsTabsOptionsEnum.overview,
                }),
              )
            }
          >
            {translate('text_6411e6b530cb47007488b027')}
          </Button>
          <Button
            disabled={!formikProps.isValid || !formHasAtLeastOneFeeChecked}
            fullWidth
            onClick={formikProps.submitForm}
            data-test={SUBMIT_BUTTON_TEST_ID}
          >
            {translate('text_636bedf292786b19d3398f12')}
          </Button>
        </div>
      </CenteredPage.StickyFooter>

      <WarningDialog
        ref={warningDialogRef}
        title={translate('text_636bdf192a28e7cf28abf00d')}
        description={translate('text_636bed940028096908b735ed')}
        continueText={translate('text_636beda08285f03477c7e25e')}
        onContinue={() =>
          navigate(
            generatePath(CUSTOMER_INVOICE_DETAILS_ROUTE, {
              customerId: customerId as string,
              invoiceId: invoiceId as string,
              tab: CustomerInvoiceDetailsTabsOptionsEnum.overview,
            }),
          )
        }
      />
    </div>
  )
}

export default CreateCreditNote
