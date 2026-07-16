import { useStore } from '@tanstack/react-form'
import { FC, useRef } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Chip } from '~/components/designSystem/Chip'
import { Selector, SelectorActions } from '~/components/designSystem/Selector'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { ProgressiveBillingFormValues } from '~/components/plans/drawers/progressiveBilling/constants'
import { mapFormThresholdsToDrawerValues } from '~/components/plans/drawers/progressiveBilling/mapToDrawerValues'
import {
  ProgressiveBillingDrawer,
  ProgressiveBillingDrawerRef,
} from '~/components/plans/drawers/progressiveBilling/ProgressiveBillingDrawer'
import { ProgressiveBillingPremiumGate } from '~/components/plans/ProgressiveBillingPremiumGate'
import { PremiumIntegrationTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { PlanFormType } from '~/hooks/plans/usePlanForm'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

export const OPEN_PROGRESSIVE_BILLING_DRAWER_TEST_ID = 'open-progressive-billing-drawer'
export const ADD_PROGRESSIVE_BILLING_TEST_ID = 'add-progressive-billing'

interface ProgressiveBillingSectionProps {
  form: PlanFormType
}

export const ProgressiveBillingSection: FC<ProgressiveBillingSectionProps> = ({ form }) => {
  const { translate } = useInternationalization()
  const { organization: { premiumIntegrations } = {} } = useOrganizationInfos()
  const progressiveBillingDrawerRef = useRef<ProgressiveBillingDrawerRef>(null)

  const nonRecurringUsageThresholds = useStore(
    form.store,
    (s) => s.values.nonRecurringUsageThresholds,
  )
  const recurringUsageThreshold = useStore(form.store, (s) => s.values.recurringUsageThreshold)

  const hasThresholds = !!nonRecurringUsageThresholds?.length || !!recurringUsageThreshold

  const hasPremiumIntegration = !!premiumIntegrations?.includes(
    PremiumIntegrationTypeEnum.ProgressiveBilling,
  )

  const thresholdCount =
    (nonRecurringUsageThresholds?.length ?? 0) + (recurringUsageThreshold ? 1 : 0)

  const handleDelete = () => {
    form.setFieldValue('nonRecurringUsageThresholds', undefined)
    form.setFieldValue('recurringUsageThreshold', undefined)
  }

  const handleDrawerSave = (values: ProgressiveBillingFormValues) => {
    form.setFieldValue('nonRecurringUsageThresholds', values.nonRecurringUsageThresholds)
    form.setFieldValue('recurringUsageThreshold', values.recurringUsageThreshold)
  }

  const openDrawer = () => {
    progressiveBillingDrawerRef.current?.openDrawer(
      mapFormThresholdsToDrawerValues(nonRecurringUsageThresholds, recurringUsageThreshold),
    )
  }

  return (
    <CenteredPage.PageSection>
      <CenteredPage.PageSectionTitle
        title={translate('text_1724179887722baucvj7bvc1')}
        description={translate('text_1724179887723kdf3nisf6hp')}
      />

      {hasThresholds && hasPremiumIntegration && (
        <Selector
          icon="table-horizontale"
          title={translate('text_1724179887722baucvj7bvc1')}
          subtitle={translate('text_1773950414511euzjefq877r', { thresholdCount }, thresholdCount)}
          endContent={
            <div className="flex items-center gap-3">
              <Chip label={translate('text_17756567905528w3193xcurh')} />
              <Button icon="chevron-right-filled" variant="quaternary" tabIndex={-1} />
            </div>
          }
          hoverActions={
            <SelectorActions
              actions={[
                {
                  icon: 'trash',
                  tooltipCopy: translate('text_63aa085d28b8510cd46443ff'),
                  onClick: handleDelete,
                },
                {
                  icon: 'pen',
                  tooltipCopy: translate('text_63e51ef4985f0ebd75c212fc'),
                  onClick: () => openDrawer(),
                },
              ]}
            />
          }
          data-test={OPEN_PROGRESSIVE_BILLING_DRAWER_TEST_ID}
          onClick={() => openDrawer()}
        />
      )}

      {!hasThresholds && !hasPremiumIntegration && <ProgressiveBillingPremiumGate />}

      {!hasThresholds && hasPremiumIntegration && (
        <Button
          fitContent
          variant="inline"
          startIcon="plus"
          data-test={ADD_PROGRESSIVE_BILLING_TEST_ID}
          onClick={() => {
            progressiveBillingDrawerRef.current?.openDrawer()
          }}
        >
          {translate('text_1724233213996upb98e8b8xx')}
        </Button>
      )}

      <ProgressiveBillingDrawer
        ref={progressiveBillingDrawerRef}
        onSave={handleDrawerSave}
        onDelete={handleDelete}
      />
    </CenteredPage.PageSection>
  )
}

ProgressiveBillingSection.displayName = 'ProgressiveBillingSection'
