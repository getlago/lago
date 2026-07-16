import { gql } from '@apollo/client'
import { FC, useMemo } from 'react'

import { Card } from '~/components/designSystem/Card'
import { NavigationTab, TabManagedBy } from '~/components/designSystem/NavigationTab'
import { Typography } from '~/components/designSystem/Typography'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import PremiumFeature from '~/components/premium/PremiumFeature'
import {
  SubscriptionForProgressiveBillingTabFragment,
  SubscriptionForUseProgressiveBillingTabFragmentDoc,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { useSubscriptionProgressiveBillingTab } from './hooks/useSubscriptionProgressiveBillingTab'
import { RecurringThresholdsTable } from './RecurringThresholdsTable'
import { SubscriptionProgressiveBillingTabThresholdsHeader } from './SubscriptionProgressiveBillingTabThresholdsHeader'
import { ThresholdsTable } from './ThresholdsTable'

// Test ID constants
export const PROGRESSIVE_BILLING_TAB_TEST_ID = 'progressive-billing-tab'
export const PROGRESSIVE_BILLING_FREEMIUM_BLOCK_TEST_ID = 'progressive-billing-freemium-block'
export const PROGRESSIVE_BILLING_DISABLED_MESSAGE_TEST_ID = 'progressive-billing-disabled-message'
export const PROGRESSIVE_BILLING_NO_THRESHOLDS_EMPTY_TEST_ID =
  'progressive-billing-no-thresholds-empty'
export const PROGRESSIVE_BILLING_NO_PLAN_THRESHOLDS_EMPTY_TEST_ID =
  'progressive-billing-no-plan-thresholds-empty'

gql`
  fragment SubscriptionForProgressiveBillingTab on Subscription {
    id
    progressiveBillingDisabled
    usageThresholds {
      id
      recurring
    }
    plan {
      id
      amountCurrency
      applicableUsageThresholds {
        id
        recurring
      }
    }

    ...SubscriptionForUseProgressiveBillingTab
  }

  ${SubscriptionForUseProgressiveBillingTabFragmentDoc}
`

interface SubscriptionProgressiveBillingTabProps {
  subscription?: SubscriptionForProgressiveBillingTabFragment | null
  loading: boolean
}

export const SubscriptionProgressiveBillingTab: FC<SubscriptionProgressiveBillingTabProps> = ({
  subscription,
  loading,
}) => {
  const { translate } = useInternationalization()
  const {
    currency,
    hasPremiumIntegration,
    nonRecurringPlanThresholds,
    nonRecurringSubscriptionThresholds,
    planThresholds,
    recurringPlanThresholds,
    recurringSubscriptionThresholds,
    subscriptionThresholds,
  } = useSubscriptionProgressiveBillingTab({ subscription })

  const tabs = useMemo(() => {
    const isProgressiveBillingDisabled = subscription?.progressiveBillingDisabled
    const hasPlanThresholds = !!planThresholds.length
    const hasSubscriptionThresholds = !!subscriptionThresholds.length
    const hasAnyThresholds = hasSubscriptionThresholds || hasPlanThresholds
    const displayPlanEmptyState = !subscription?.progressiveBillingDisabled && !hasAnyThresholds
    const displaySubscriptionThresholdTable = !isProgressiveBillingDisabled && hasAnyThresholds

    return [
      {
        title: translate('text_1769712384134peknn5jyojg'),
        hidden: !subscriptionThresholds.length && !subscription?.progressiveBillingDisabled,
        component: (
          <div className="flex flex-col gap-4 p-4">
            {isProgressiveBillingDisabled && (
              <Typography
                data-test={PROGRESSIVE_BILLING_DISABLED_MESSAGE_TEST_ID}
                variant="body"
                color="grey500"
              >
                {translate('text_1769714542183sxbznn2i3v0')}
              </Typography>
            )}
            {displaySubscriptionThresholdTable && (
              <>
                <ThresholdsTable
                  thresholds={nonRecurringSubscriptionThresholds}
                  currency={currency}
                />

                {recurringSubscriptionThresholds.length > 0 && (
                  <RecurringThresholdsTable
                    thresholds={recurringSubscriptionThresholds}
                    currency={currency}
                  />
                )}
              </>
            )}
          </div>
        ),
      },
      {
        title: translate('text_17697123841349drggrw2qur'),
        component: (
          <div className="flex flex-col gap-4 p-4">
            {displayPlanEmptyState && (
              <Typography
                data-test={PROGRESSIVE_BILLING_NO_THRESHOLDS_EMPTY_TEST_ID}
                variant="body"
                color="grey500"
              >
                {translate('text_1770217073925sgkyyd8peck')}
              </Typography>
            )}
            {!displayPlanEmptyState && !hasPlanThresholds && (
              <Typography
                data-test={PROGRESSIVE_BILLING_NO_PLAN_THRESHOLDS_EMPTY_TEST_ID}
                variant="body"
                color="grey500"
              >
                {translate('text_1770220776577i5r9mz1h3rr')}
              </Typography>
            )}
            {!displayPlanEmptyState && !!hasPlanThresholds && (
              <>
                <ThresholdsTable thresholds={nonRecurringPlanThresholds} currency={currency} />

                {recurringPlanThresholds.length > 0 && (
                  <RecurringThresholdsTable
                    thresholds={recurringPlanThresholds}
                    currency={currency}
                  />
                )}
              </>
            )}
          </div>
        ),
      },
    ]
  }, [
    subscription?.progressiveBillingDisabled,
    subscriptionThresholds.length,
    planThresholds.length,
    translate,
    nonRecurringSubscriptionThresholds,
    currency,
    recurringSubscriptionThresholds,
    nonRecurringPlanThresholds,
    recurringPlanThresholds,
  ])

  if (loading || !subscription) {
    return <DetailsPage.Skeleton />
  }

  return (
    <section data-test={PROGRESSIVE_BILLING_TAB_TEST_ID} className="flex flex-col gap-6 pt-6">
      <div className="flex flex-col items-start justify-between gap-4">
        <div className="flex flex-col gap-1">
          <Typography variant="subhead1">{translate('text_1724179887722baucvj7bvc1')}</Typography>
          <Typography variant="caption" color="grey600">
            {translate('text_1724179887723kdf3nisf6hp')}
          </Typography>
        </div>

        {!hasPremiumIntegration && (
          <PremiumFeature
            data-test={PROGRESSIVE_BILLING_FREEMIUM_BLOCK_TEST_ID}
            title={translate('text_1724345142892pcnx5m2k3r2')}
            description={translate('text_1724345142892ljzi79afhmc')}
            feature={translate('text_1724179887722baucvj7bvc1')}
          />
        )}

        {hasPremiumIntegration && (
          <Card className="w-full gap-0 p-0">
            <SubscriptionProgressiveBillingTabThresholdsHeader subscription={subscription} />

            <NavigationTab
              // Margin top is here to respect the design implementation. Setting a different height on the navigation tab breaks the selected tab indicator. Using margin was the easiest approach.
              className="mt-1 px-4"
              managedBy={TabManagedBy.INDEX}
              tabs={tabs}
            />
          </Card>
        )}
      </div>
    </section>
  )
}
