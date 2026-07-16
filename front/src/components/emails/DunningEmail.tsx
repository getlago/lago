import { gql } from '@apollo/client'
import { FC } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Table } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { LocaleEnum } from '~/core/translations'
import {
  CurrencyEnum,
  CustomerForDunningEmailFragment,
  InvoicesForDunningEmailFragment,
  OrganizationForDunningEmailFragment,
  ProviderTypeEnum,
} from '~/generated/graphql'
import { useContextualLocale } from '~/hooks/core/useContextualLocale'
import { tw } from '~/styles/utils'

gql`
  fragment CustomerForDunningEmail on Customer {
    displayName
    paymentProvider
    netPaymentTerm
    billingConfiguration {
      documentLocale
    }
  }

  fragment OrganizationForDunningEmail on CurrentOrganization {
    name
    logoUrl
    email
    netPaymentTerm
    billingConfiguration {
      documentLocale
    }
  }

  fragment InvoicesForDunningEmail on Invoice {
    id
    number
    totalDueAmountCents
    currency
  }
`

export interface DunningEmailProps {
  locale: LocaleEnum
  invoices: InvoicesForDunningEmailFragment[]
  customer?: CustomerForDunningEmailFragment
  // Omit the netPaymentTerm from the organization and add it possible string
  organization?: Omit<OrganizationForDunningEmailFragment, 'netPaymentTerm'> & {
    netPaymentTerm: OrganizationForDunningEmailFragment['netPaymentTerm'] | string
  }
  currency: CurrencyEnum
  overdueAmount: number
}

export const DunningEmailSkeleton = () => {
  return (
    <>
      <Skeleton variant="text" color="dark" className="w-26" />
      <Skeleton variant="text" color="dark" />
      <Skeleton variant="text" color="dark" className="w-40" />
    </>
  )
}

export const DunningEmail: FC<DunningEmailProps> = ({
  locale,
  customer,
  organization,
  invoices,
  overdueAmount,
  currency,
}) => {
  const { translateWithContextualLocal: translate } = useContextualLocale(locale)

  const paragraphStyle = tw('font-email text-base font-normal')
  const captionStyle = tw('font-email text-sm font-normal')
  const headlineStyle = tw('font-email text-4xl font-bold')

  const formattedOverdueAmount = intlFormatNumber(overdueAmount, {
    currency,
    locale,
    currencyDisplay: 'narrowSymbol',
  })

  const netPaymentTerm = customer?.netPaymentTerm ?? organization?.netPaymentTerm

  return (
    <>
      <div className="flex flex-col gap-6 pb-8 shadow-b">
        <Typography className={paragraphStyle} color="textSecondary">
          {translate('text_66b378e748cda1004ff00db0', { customerName: customer?.displayName })}
        </Typography>
        <Typography className={paragraphStyle} color="textSecondary">
          {translate('text_66b378e748cda1004ff00db1', { organizationName: organization?.name })}
        </Typography>
        <Typography className={paragraphStyle} color="textSecondary">
          {translate('text_66b378e748cda1004ff00db2', { amount: formattedOverdueAmount })}
        </Typography>
        <Typography className={paragraphStyle} color="textSecondary">
          {translate(
            'text_66b378e748cda1004ff00db3',
            { netPaymentTerm: netPaymentTerm },
            typeof netPaymentTerm === 'number'
              ? netPaymentTerm
              : // If netPaymentTerm is a string (fake data), the plural version is returned
                2,
          )}
        </Typography>
        <Typography className={paragraphStyle} color="textSecondary">
          {translate('text_66b378e748cda1004ff00db4')}
        </Typography>
        <Typography className={paragraphStyle} color="textSecondary">
          {translate('text_66b378e748cda1004ff00db5')}
        </Typography>
      </div>

      <div className="flex flex-col items-start gap-4">
        <div>
          <Typography className={captionStyle}>
            {translate('text_66b378e748cda1004ff00db6')}
          </Typography>
          <Typography className={headlineStyle} color="textSecondary">
            {formattedOverdueAmount}
          </Typography>
        </div>

        {!!customer?.paymentProvider &&
          customer.paymentProvider !== ProviderTypeEnum.Gocardless && (
            <Button
              className={tw('pointer-events-none cursor-default')}
              variant="primary"
              size="medium"
            >
              {translate('text_66b378e748cda1004ff00db8')}
            </Button>
          )}
      </div>
      <Table
        name="email-preview"
        containerSize={{ default: 0 }}
        rowSize={48}
        data={invoices}
        columns={[
          {
            key: 'number',
            title: (
              <Typography className={captionStyle} noWrap>
                {translate('text_6419c64eace749372fc72b3c')}
              </Typography>
            ),
            maxSpace: true,
            content: ({ number }) => (
              <Typography className={captionStyle} color="primary600" noWrap>
                {number}
              </Typography>
            ),
          },
          {
            key: 'totalDueAmountCents',
            textAlign: 'right',
            title: (
              <Typography className={captionStyle} noWrap>
                {translate('text_17374735502775afvcm9pqxk')}
              </Typography>
            ),
            content: (row) => (
              <Typography className={captionStyle} color="textSecondary" noWrap>
                {intlFormatNumber(
                  deserializeAmount(row.totalDueAmountCents, row.currency || currency),
                  {
                    currency: row.currency || currency,
                    locale: locale,
                    currencyDisplay: 'narrowSymbol',
                  },
                )}
              </Typography>
            ),
          },
        ]}
      />

      {organization?.email && (
        <div className={tw('text-center')}>
          <Typography className={captionStyle} component="span">
            {translate('text_64188b3d9735d5007d712276')}
          </Typography>
          <Typography className={captionStyle} component="span">{` `}</Typography>
          <Typography className={captionStyle} component="span" color="primary600">
            {organization?.email}
          </Typography>
        </div>
      )}
    </>
  )
}
