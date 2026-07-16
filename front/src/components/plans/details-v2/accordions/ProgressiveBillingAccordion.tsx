import { useRef } from 'react'

import { ProgressiveBillingFormValues } from '~/components/plans/drawers/progressiveBilling/constants'
import { mapPlanThresholdsToDrawerValues } from '~/components/plans/drawers/progressiveBilling/mapToDrawerValues'
import {
  ProgressiveBillingDrawer,
  ProgressiveBillingDrawerRef,
} from '~/components/plans/drawers/progressiveBilling/ProgressiveBillingDrawer'
import { ProgressiveBillingInfo } from '~/components/plans/ProgressiveBillingInfo'
import { ProgressiveBillingPremiumGate } from '~/components/plans/ProgressiveBillingPremiumGate'
import { PlanFormProvider } from '~/contexts/PlanFormContext'
import {
  CurrencyEnum,
  PlanDetailsV2Fragment,
  PremiumIntegrationTypeEnum,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAccordionPermissions } from '~/hooks/plans/useAccordionPermissions'
import { useUpdatePlanWithCascade } from '~/hooks/plans/useUpdatePlanWithCascade'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

import { SectionAccordion } from '../shared/SectionAccordion'
import { SectionHeader } from '../shared/SectionHeader'
import { PlanDetailsV2SectionId } from '../sidebarSections'

type ProgressiveBillingAccordionProps = {
  plan: PlanDetailsV2Fragment
  isInSubscriptionForm?: boolean
}

export const ProgressiveBillingAccordion = ({
  plan,
  isInSubscriptionForm = false,
}: ProgressiveBillingAccordionProps) => {
  const { translate } = useInternationalization()
  const { organization: { premiumIntegrations } = {} } = useOrganizationInfos()
  const { canCreate, canUpdate, canDelete } = useAccordionPermissions(isInSubscriptionForm)
  const drawerRef = useRef<ProgressiveBillingDrawerRef>(null)

  const currency = plan.amountCurrency || CurrencyEnum.Usd
  const hasThresholds = !!plan.usageThresholds?.length
  const thresholdCount = plan.usageThresholds?.length ?? 0
  const hasPremiumIntegration = !!premiumIntegrations?.includes(
    PremiumIntegrationTypeEnum.ProgressiveBilling,
  )

  const { form, applyAndSubmit } = useUpdatePlanWithCascade({
    plan,
    includeAdvancedFields: true,
  })

  const handleSave = (values: ProgressiveBillingFormValues): Promise<boolean> =>
    applyAndSubmit(() => {
      form.setFieldValue('nonRecurringUsageThresholds', values.nonRecurringUsageThresholds)
      form.setFieldValue('recurringUsageThreshold', values.recurringUsageThreshold)
    })

  const handleDelete = (): Promise<boolean> =>
    applyAndSubmit(() => {
      form.setFieldValue('nonRecurringUsageThresholds', undefined)
      form.setFieldValue('recurringUsageThreshold', undefined)
    })

  const openEditDrawer = () => {
    drawerRef.current?.openDrawer(mapPlanThresholdsToDrawerValues(plan.usageThresholds, currency))
  }

  return (
    <section
      id={PlanDetailsV2SectionId.ProgressiveBilling}
      className="flex scroll-mt-12 flex-col gap-6"
    >
      <SectionHeader
        title={translate('text_1724179887722baucvj7bvc1')}
        description={translate('text_1724179887723kdf3nisf6hp')}
        action={{
          label: translate('text_1724233213996upb98e8b8xx'),
          onClick: () => drawerRef.current?.openDrawer(),
          hidden: !canCreate || hasThresholds || !hasPremiumIntegration,
          startIcon: 'plus',
        }}
      />

      {!hasThresholds && !hasPremiumIntegration && <ProgressiveBillingPremiumGate />}

      {hasThresholds && (
        <SectionAccordion
          icon="table-horizontale"
          title={translate('text_1724179887722baucvj7bvc1')}
          subtitle={translate('text_1773950414511euzjefq877r', { thresholdCount }, thresholdCount)}
          actions={[
            {
              label: translate('text_63e51ef4985f0ebd75c212fc'),
              startIcon: 'pen',
              onClick: openEditDrawer,
              hidden: !canUpdate,
            },
            {
              label: translate('text_63ea0f84f400488553caa786'),
              startIcon: 'trash',
              onClick: () => void handleDelete(),
              hidden: !canDelete,
            },
          ]}
        >
          <ProgressiveBillingInfo plan={plan} currency={currency} />
        </SectionAccordion>
      )}

      <PlanFormProvider currency={currency} interval={plan.interval}>
        <ProgressiveBillingDrawer
          ref={drawerRef}
          onSave={handleSave}
          onDelete={() => void handleDelete()}
        />
      </PlanFormProvider>
    </section>
  )
}
