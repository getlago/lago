import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { useNavigate } from '~/core/router'
import { InvoicePaymentStatusTypeEnum, InvoiceStatusTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { tw } from '~/styles/utils'

import { useFilters } from './useFilters'

const QuickFilter = ({
  children,
  isSelected,
  onClick,
}: {
  children: React.ReactNode
  isSelected: boolean
  onClick: () => void
}) => (
  <Button
    className={tw({
      'text-blue-600 [&>div]:text-blue-600': isSelected,
    })}
    variant="tertiary"
    align="left"
    onClick={onClick}
  >
    {children}
  </Button>
)

enum InvoiceQuickFilterEnum {
  Outstanding = 'outstanding',
  Succeeded = 'succeeded',
  Draft = 'draft',
  PaymentOverdue = 'paymentOverdue',
  Voided = 'voided',
  PaymentDisputeLost = 'paymentDisputeLost',
}

const invoiceQuickFilterTranslations = {
  [InvoiceQuickFilterEnum.Outstanding]: 'text_666c5b12fea4aa1e1b26bf52',
  [InvoiceQuickFilterEnum.Succeeded]: 'text_63ac86d797f728a87b2f9fa1',
  [InvoiceQuickFilterEnum.Draft]: 'text_63ac86d797f728a87b2f9f91',
  [InvoiceQuickFilterEnum.PaymentOverdue]: 'text_666c5b12fea4aa1e1b26bf55',
  [InvoiceQuickFilterEnum.Voided]: 'text_6376641a2a9c70fff5bddcd5',
  [InvoiceQuickFilterEnum.PaymentDisputeLost]: 'text_66141e30699a0631f0b2ed32',
}

const quickFilterMapping: Record<
  InvoiceQuickFilterEnum,
  {
    [key: string]: unknown
  }
> = {
  [InvoiceQuickFilterEnum.Draft]: {
    status: InvoiceStatusTypeEnum.Draft,
  },
  [InvoiceQuickFilterEnum.Outstanding]: {
    paymentStatus: [InvoicePaymentStatusTypeEnum.Failed, InvoicePaymentStatusTypeEnum.Pending],
    status: InvoiceStatusTypeEnum.Finalized,
  },
  [InvoiceQuickFilterEnum.PaymentOverdue]: {
    paymentOverdue: true,
  },
  [InvoiceQuickFilterEnum.Succeeded]: {
    paymentStatus: InvoicePaymentStatusTypeEnum.Succeeded,
    status: InvoiceStatusTypeEnum.Finalized,
  },
  [InvoiceQuickFilterEnum.Voided]: {
    status: InvoiceStatusTypeEnum.Voided,
  },
  [InvoiceQuickFilterEnum.PaymentDisputeLost]: {
    paymentDisputeLost: true,
  },
}

export const InvoiceStatusQuickFilter = () => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const { resetFilters, isQuickFilterActive, buildQuickFilterUrlParams, hasAppliedFilters } =
    useFilters()

  return (
    <>
      <QuickFilter isSelected={!hasAppliedFilters} onClick={resetFilters}>
        <Typography variant="captionHl" color="grey600">
          {translate('text_63ac86d797f728a87b2f9f8b')}
        </Typography>
      </QuickFilter>
      {Object.entries(quickFilterMapping).map(([key, value]) => (
        <QuickFilter
          key={key}
          isSelected={isQuickFilterActive(value)}
          onClick={() => navigate({ search: buildQuickFilterUrlParams(value) })}
        >
          <Typography variant="captionHl" color="grey600">
            {translate(invoiceQuickFilterTranslations[key as InvoiceQuickFilterEnum])}
          </Typography>
        </QuickFilter>
      ))}
    </>
  )
}
