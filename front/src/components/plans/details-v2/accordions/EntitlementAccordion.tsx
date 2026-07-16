import { forwardRef, useImperativeHandle, useRef } from 'react'

import {
  removeEntitlementByFeatureCode,
  upsertEntitlement,
} from '~/components/plans/drawers/featureEntitlement/entitlementHelpers'
import {
  FeatureEntitlementDrawer,
  FeatureEntitlementDrawerRef,
  FeatureEntitlementFormValues,
} from '~/components/plans/drawers/featureEntitlement/FeatureEntitlementDrawer'
import { EntitlementInfo } from '~/components/plans/EntitlementInfo'
import { PlanDetailsV2Fragment } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAccordionPermissions } from '~/hooks/plans/useAccordionPermissions'
import { useUpdatePlanWithCascade } from '~/hooks/plans/useUpdatePlanWithCascade'

import { SectionAccordion } from '../shared/SectionAccordion'
import { SectionHeader } from '../shared/SectionHeader'
import { getEntitlementSectionId, PlanDetailsV2SectionId } from '../sidebarSections'

export type EntitlementAccordionRef = {
  openCreate: () => void
}

type EntitlementAccordionProps = {
  plan: PlanDetailsV2Fragment
  isInSubscriptionForm?: boolean
}

export const EntitlementAccordion = forwardRef<EntitlementAccordionRef, EntitlementAccordionProps>(
  ({ plan, isInSubscriptionForm = false }, ref) => {
    const { translate } = useInternationalization()
    const { canCreate, canUpdate, canDelete } = useAccordionPermissions(isInSubscriptionForm)
    const drawerRef = useRef<FeatureEntitlementDrawerRef>(null)

    const openCreate = () => drawerRef.current?.openDrawer()

    useImperativeHandle(ref, () => ({ openCreate }))

    const entitlements = plan.entitlements ?? []

    const { form, applyAndSubmit } = useUpdatePlanWithCascade({
      plan,
      includeAdvancedFields: true,
    })

    const handleSave = (values: FeatureEntitlementFormValues): Promise<boolean> =>
      applyAndSubmit(() => {
        form.setFieldValue(
          'entitlements',
          upsertEntitlement(form.state.values.entitlements, {
            featureId: values.featureId,
            featureName: values.featureName,
            featureCode: values.featureCode,
            privileges: values.privileges,
          }),
        )
      })

    const handleDelete = (featureCode: string): Promise<boolean> =>
      applyAndSubmit(() =>
        form.setFieldValue(
          'entitlements',
          removeEntitlementByFeatureCode(form.state.values.entitlements, featureCode),
        ),
      )

    return (
      <section
        id={PlanDetailsV2SectionId.Entitlements}
        className="flex scroll-mt-12 flex-col gap-6"
      >
        <SectionHeader
          title={translate('text_63e26d8308d03687188221a6')}
          description={translate('text_17538642230602p03937fj0f')}
          action={{
            label: translate('text_1753864223060devvklm7vk0'),
            onClick: () => drawerRef.current?.openDrawer(),
            hidden: !canCreate,
            startIcon: 'plus',
          }}
        />

        {entitlements.map((entitlement) => (
          <SectionAccordion
            key={`entitlement-${entitlement.code}`}
            id={getEntitlementSectionId(entitlement.code)}
            icon="switch"
            title={entitlement.name || entitlement.code}
            subtitle={entitlement.code}
            actions={[
              {
                label: translate('text_63e51ef4985f0ebd75c212fc'),
                startIcon: 'pen',
                onClick: () =>
                  drawerRef.current?.openDrawer({
                    featureId: '',
                    featureName: entitlement.name || '',
                    featureCode: entitlement.code,
                    privileges: entitlement.privileges.map((p) => ({
                      privilegeCode: p.code,
                      privilegeName: p.name,
                      value: p.value,
                      valueType: p.valueType,
                      config: p.config,
                    })),
                  }),
                hidden: !canUpdate,
              },
              {
                label: translate('text_63ea0f84f400488553caa786'),
                startIcon: 'trash',
                onClick: () => void handleDelete(entitlement.code),
                hidden: !canDelete,
              },
            ]}
          >
            <EntitlementInfo entitlement={entitlement} />
          </SectionAccordion>
        ))}

        <FeatureEntitlementDrawer
          ref={drawerRef}
          existingFeatureCodes={entitlements.map((e) => e.code)}
          onSave={handleSave}
          onDelete={(featureCode) => void handleDelete(featureCode)}
        />
      </section>
    )
  },
)

EntitlementAccordion.displayName = 'EntitlementAccordion'
