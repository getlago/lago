import { gql } from '@apollo/client'
import { Icon } from 'lago-design-system'
import { DateTime } from 'luxon'
import { memo } from 'react'
import { generatePath } from 'react-router-dom'

import { ConditionalWrapper } from '~/components/ConditionalWrapper'
import { Status, StatusType } from '~/components/designSystem/Status'
import { Typography } from '~/components/designSystem/Typography'
import { invoiceStatusMapping, paymentStatusMapping } from '~/core/constants/statusInvoiceMapping'
import { formatAddress } from '~/core/formats/formatAddress'
import { CUSTOMER_DETAILS_ROUTE, Link } from '~/core/router'
import {
  CustomerAccountTypeEnum,
  InvoiceForInvoiceInfosFragment,
  InvoiceStatusTypeEnum,
  InvoiceTypeEnum,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useFormatterDateHelper } from '~/hooks/helpers/useFormatterDateHelper'

import { DetailsPage } from '../layouts/DetailsPage'

gql`
  fragment InvoiceForInvoiceInfos on Invoice {
    number
    invoiceType
    purchaseOrderNumber
    issuingDate
    paymentDueDate
    paymentOverdue
    status
    totalPaidAmountCents
    totalDueAmountCents
    paymentStatus
    paymentDisputeLostAt
    taxProviderVoidable
    errorDetails {
      errorCode
      errorDetails
    }
    customer {
      id
      name
      displayName
      legalNumber
      legalName
      taxIdentificationNumber
      email
      addressLine1
      addressLine2
      state
      country
      city
      zipcode
      applicableTimezone
      deletedAt
      accountType
    }
  }
`

interface InvoiceCustomerInfosProps {
  invoice?: InvoiceForInvoiceInfosFragment | null
}

export const InvoiceCustomerInfos = memo(({ invoice }: InvoiceCustomerInfosProps) => {
  const { customer } = invoice || {}
  const { formattedDateWithTimezone } = useFormatterDateHelper()
  const { translate } = useInternationalization()

  const customerName = customer?.displayName
  const customerIsPartner = customer?.accountType === CustomerAccountTypeEnum.Partner

  const formattedAddress = formatAddress({
    addressLine1: customer?.addressLine1,
    addressLine2: customer?.addressLine2,
    city: customer?.city,
    country: customer?.country,
    state: customer?.state,
    zipcode: customer?.zipcode,
  })

  return (
    <DetailsPage.Overview
      leftColumn={
        <>
          {!!customer && !!customerName && (
            <DetailsPage.OverviewLine
              title={translate(
                customerIsPartner
                  ? 'text_17385950520558ttf6sv58s0'
                  : 'text_634687079be251fdb43833cb',
              )}
              value={
                <ConditionalWrapper
                  condition={!!customer.deletedAt}
                  validWrapper={(children) => <>{children}</>}
                  invalidWrapper={(children) => (
                    <Link
                      className="*:text-blue-600"
                      to={generatePath(CUSTOMER_DETAILS_ROUTE, {
                        customerId: customer.id,
                      })}
                    >
                      {children}
                    </Link>
                  )}
                >
                  {customerName}
                </ConditionalWrapper>
              }
            />
          )}
          {!!customer?.legalName && (
            <DetailsPage.OverviewLine
              title={translate('text_634687079be251fdb43833d7')}
              value={customer?.legalName}
            />
          )}
          {!!customer?.legalNumber && (
            <DetailsPage.OverviewLine
              title={translate('text_647ddd5220412a009bfd36f4')}
              value={customer?.legalNumber}
            />
          )}
          {!!customer?.email && (
            <DetailsPage.OverviewLine
              title={translate('text_634687079be251fdb43833e3')}
              value={customer?.email.split(',').join(', ')}
            />
          )}
          {!!formattedAddress && (
            <DetailsPage.OverviewLine
              title={translate('text_634687079be251fdb43833ef')}
              value={formattedAddress}
            />
          )}
        </>
      }
      rightColumn={
        <>
          {customer?.taxIdentificationNumber && (
            <DetailsPage.OverviewLine
              title={translate('text_648053ee819b60364c675cf1')}
              value={customer?.taxIdentificationNumber}
            />
          )}
          {invoice?.number && (
            <DetailsPage.OverviewLine
              title={translate('text_634687079be251fdb43833fb')}
              value={invoice?.number}
            />
          )}
          {invoice?.invoiceType === InvoiceTypeEnum.OneOff && (
            <DetailsPage.OverviewLine
              title={translate('text_17822197712867qhfbaf9fpk')}
              value={invoice?.purchaseOrderNumber || '-'}
            />
          )}
          {invoice?.issuingDate && (
            <DetailsPage.OverviewLine
              title={translate('text_634687079be251fdb4383407')}
              value={formattedDateWithTimezone(invoice.issuingDate, customer?.applicableTimezone)}
            />
          )}
          {invoice?.paymentDueDate && (
            <DetailsPage.OverviewLine
              title={translate('text_666c5d227d073444e90be894')}
              value={
                <div className="flex flex-wrap items-baseline gap-3">
                  <Typography variant="body" color="grey700">
                    {formattedDateWithTimezone(
                      invoice.paymentDueDate,
                      customer?.applicableTimezone,
                    )}
                  </Typography>
                  {invoice?.paymentOverdue && <Status type={StatusType.danger} label="overdue" />}
                </div>
              }
            />
          )}
          {!!invoice?.status && (
            <DetailsPage.OverviewLine
              title={translate('text_65269b6afe1fda4ad9bf672b')}
              value={<Status {...invoiceStatusMapping({ status: invoice.status })} />}
            />
          )}
          <DetailsPage.OverviewLine
            title={translate('text_63eba8c65a6c8043feee2a0f')}
            value={
              invoice?.status === InvoiceStatusTypeEnum.Finalized ? (
                <Status
                  {...paymentStatusMapping({
                    status: invoice.status,
                    paymentStatus: invoice.paymentStatus,
                    totalPaidAmountCents: invoice.totalPaidAmountCents,
                    totalDueAmountCents: invoice.totalDueAmountCents,
                  })}
                />
              ) : (
                <Typography variant="body" color="grey700">
                  -
                </Typography>
              )
            }
          />
          {!!invoice?.paymentDisputeLostAt && (
            <DetailsPage.OverviewLine
              title={translate('text_66141e30699a0631f0b2ed32')}
              value={
                <div className="flex flex-wrap items-center gap-2">
                  <Icon name="warning-filled" color="warning" />
                  {translate('text_66141e30699a0631f0b2ed2c', {
                    date: DateTime.fromISO(invoice?.paymentDisputeLostAt).toFormat('LLL. dd, yyyy'),
                  })}
                </div>
              }
            />
          )}
        </>
      }
    />
  )
})

InvoiceCustomerInfos.displayName = 'InvoiceCustomerInfos'
