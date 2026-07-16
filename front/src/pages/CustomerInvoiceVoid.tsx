import { gql } from '@apollo/client'
import { generatePath, useParams } from 'react-router-dom'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { Status } from '~/components/designSystem/Status'
import { Table } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { addToast } from '~/core/apolloClient'
import { paymentStatusMapping } from '~/core/constants/statusInvoiceMapping'
import { CustomerInvoiceDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { CUSTOMER_INVOICE_DETAILS_ROUTE, Link, useNavigate } from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { intlFormatDateTime } from '~/core/timezone'
import { isPrepaidCredit } from '~/core/utils/invoiceUtils'
import { regeneratePath } from '~/core/utils/regenerateUtils'
import {
  AllInvoiceDetailsForCustomerInvoiceDetailsFragmentDoc,
  CurrencyEnum,
  Invoice,
  InvoiceForVoidInvoiceDialogFragment,
  InvoiceForVoidInvoiceDialogFragmentDoc,
  InvoiceListItemFragmentDoc,
  useGetInvoiceDetailsQuery,
  useVoidInvoiceMutation,
  VoidInvoiceInput,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useLocationHistory } from '~/hooks/core/useLocationHistory'
import { useCustomerHasActiveWallet } from '~/hooks/customer/useCustomerHasActiveWallet'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import ErrorImage from '~/public/images/maneki/error.svg'
import { FormLoadingSkeleton } from '~/styles/mainObjectsForm'

gql`
  fragment InvoiceForVoidInvoiceDialog on Invoice {
    id
    number
  }

  mutation voidInvoice($input: VoidInvoiceInput!) {
    voidInvoice(input: $input) {
      id
      status
      ...InvoiceListItem
      ...AllInvoiceDetailsForCustomerInvoiceDetails
    }
  }

  # Fragments needed to refresh data from other parts of the UI
  ${InvoiceListItemFragmentDoc}
  ${AllInvoiceDetailsForCustomerInvoiceDetailsFragmentDoc}
`

const CustomerInvoiceVoid = () => {
  const { translate } = useInternationalization()
  const { goBack } = useLocationHistory()
  const { customerId, invoiceId } = useParams()
  const { timezone } = useOrganizationInfos()
  const navigate = useNavigate()
  const { isPremium } = useCurrentUser()

  const { data, loading, error } = useGetInvoiceDetailsQuery({
    variables: { id: invoiceId as string },
    skip: !invoiceId,
  })

  const hasActiveWallet = useCustomerHasActiveWallet({
    customerId,
  })

  const [voidInvoice] = useVoidInvoiceMutation({
    onCompleted(voidedData) {
      if (voidedData?.voidInvoice && customerId && invoiceId) {
        addToast({
          message: translate('text_65269b43d4d2b15dd929a254'),
          severity: 'success',
        })

        navigate(
          generatePath(CUSTOMER_INVOICE_DETAILS_ROUTE, {
            customerId,
            invoiceId,
            tab: CustomerInvoiceDetailsTabsOptionsEnum.overview,
          }),
        )
      }
    },
    update(cache, { data: invoiceData }) {
      if (!invoiceData?.voidInvoice) return

      const cacheId = `Invoice:${invoiceData?.voidInvoice.id}`

      const previousData: InvoiceForVoidInvoiceDialogFragment | null = cache.readFragment({
        id: cacheId,
        fragment: InvoiceForVoidInvoiceDialogFragmentDoc,
        fragmentName: 'InvoiceForVoidInvoiceDialog',
      })

      cache.writeFragment({
        id: cacheId,
        fragment: InvoiceForVoidInvoiceDialogFragmentDoc,
        fragmentName: 'InvoiceForVoidInvoiceDialog',
        data: {
          ...previousData,
          status: invoiceData.voidInvoice.status,
        },
      })
    },
    refetchQueries: ['getCustomerCreditNotes'],
  })

  const invoice = data?.invoice

  const currency = invoice?.currency || CurrencyEnum.Usd

  const hasActiveCustomer = !invoice?.customer?.deletedAt

  const onSubmit = async () => {
    if (invoiceId) {
      const input: VoidInvoiceInput = {
        id: invoiceId,
        generateCreditNote: false,
      }

      await voidInvoice({
        variables: {
          input,
        },
      })
    }
  }

  const canRegenerate =
    hasActiveCustomer &&
    customerId &&
    invoiceId &&
    invoice &&
    (isPrepaidCredit(invoice) ? hasActiveWallet : true)

  const onClose = () => {
    if (customerId && invoiceId) {
      goBack(
        generatePath(CUSTOMER_INVOICE_DETAILS_ROUTE, {
          customerId,
          invoiceId,
          tab: CustomerInvoiceDetailsTabsOptionsEnum.overview,
        }),
      )
    }
  }

  if (error) {
    return (
      <GenericPlaceholder
        className="pt-12"
        title={translate('text_634812d6f16b31ce5cbf4126')}
        subtitle={translate('text_634812d6f16b31ce5cbf4128')}
        buttonTitle={translate('text_634812d6f16b31ce5cbf412a')}
        buttonVariant="primary"
        buttonAction={() => location.reload()}
        image={<ErrorImage width="136" height="104" />}
      />
    )
  }

  return (
    <CenteredPage.Wrapper>
      <CenteredPage.Header>
        <Typography className="font-medium text-grey-700">
          {translate('text_65269b43d4d2b15dd929a259')}
        </Typography>

        <Button variant="quaternary" icon="close" onClick={() => onClose()} />
      </CenteredPage.Header>

      {loading && (
        <CenteredPage.Container>
          <FormLoadingSkeleton id="customer-invoice-void" />
        </CenteredPage.Container>
      )}

      {!loading && (
        <CenteredPage.Container>
          <div className="flex flex-col gap-12">
            <Alert type="warning">
              <Typography className="text-grey-700">
                {translate('text_1747902518581z70x872zret')}
              </Typography>
            </Alert>

            <div className="flex flex-col gap-1">
              <Typography variant="headline" color="grey700">
                {translate('text_1747902518582f4ekodb3ren', {
                  invoiceNumber: invoice?.number,
                })}
              </Typography>

              <Typography variant="body" color="grey600">
                {translate('text_1747902518582t5nxesgz7dd')}
                <br />
                {translate('text_1747903819929atyvhuolvwe')}
              </Typography>
            </div>

            <div className="flex flex-col gap-6">
              <Typography variant="subhead1" color="grey700">
                {translate('text_17374729448780zbfa44h1s3')}
              </Typography>

              <Table
                name="invoice"
                data={invoice ? [invoice] : []}
                containerSize={0}
                columns={[
                  {
                    key: 'paymentStatus',
                    title: translate('text_6419c64eace749372fc72b40'),
                    content: ({
                      paymentStatus,
                      status,
                      totalPaidAmountCents,
                      totalDueAmountCents,
                    }) => {
                      return (
                        <Status
                          {...paymentStatusMapping({
                            paymentStatus,
                            status,
                            totalPaidAmountCents,
                            totalDueAmountCents,
                          })}
                        />
                      )
                    },
                  },
                  {
                    key: 'number',
                    title: translate('text_64188b3d9735d5007d71226c'),
                    maxSpace: true,
                    content: ({ number: nb }) => nb,
                  },
                  {
                    key: 'totalDueAmountCents',
                    title: translate('text_17346988752182hpzppdqk9t'),
                    textAlign: 'right',
                    content: ({ totalAmountCents, totalPaidAmountCents }) => (
                      <>
                        <Typography variant="bodyHl" color="grey700">
                          {intlFormatNumber(deserializeAmount(totalAmountCents, currency), {
                            currency,
                          })}
                        </Typography>

                        <Typography variant="caption" color="grey600" className="text-nowrap">
                          {`${translate('text_1741604005109aspaz4chd7y')}: ${intlFormatNumber(
                            deserializeAmount(totalPaidAmountCents, currency),
                            {
                              currency,
                            },
                          )}`}
                        </Typography>
                      </>
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
            </div>

            {isPremium && (
              <Alert type="info">
                <Typography className="text-grey-700">
                  {translate('text_1747908642632nja67p9ig0e')}
                </Typography>
              </Alert>
            )}
          </div>
        </CenteredPage.Container>
      )}

      <CenteredPage.StickyFooter>
        <div className="flex w-full items-center justify-between">
          <div>
            {!!canRegenerate && (
              <Link to={regeneratePath(invoice as Invoice)}>
                {translate('text_1750678506388eexnh1b36o4')}
              </Link>
            )}
          </div>

          <div className="flex gap-3">
            <Button variant="quaternary" onClick={() => onClose()}>
              {translate('text_6411e6b530cb47007488b027')}
            </Button>

            <Button variant="primary" danger onClick={() => onSubmit()}>
              {translate('text_65269b43d4d2b15dd929a259')}
            </Button>
          </div>
        </div>
      </CenteredPage.StickyFooter>
    </CenteredPage.Wrapper>
  )
}

export default CustomerInvoiceVoid
