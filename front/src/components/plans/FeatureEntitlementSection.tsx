import { gql } from '@apollo/client'
import { useStore } from '@tanstack/react-form'
import { FC, useRef } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Selector, SelectorActions } from '~/components/designSystem/Selector'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import {
  removeEntitlementByFeatureCode,
  upsertEntitlement,
} from '~/components/plans/drawers/featureEntitlement/entitlementHelpers'
import {
  FeatureEntitlementDrawer,
  FeatureEntitlementDrawerRef,
  FeatureEntitlementFormValues,
} from '~/components/plans/drawers/featureEntitlement/FeatureEntitlementDrawer'
import {
  FeatureEntitlementPrivilegeForPlanFragmentDoc,
  FeatureObjectEntitlementPrivilegeForPlanFragmentDoc,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { PlanFormType } from '~/hooks/plans/usePlanForm'

export const ADD_FEATURE_ENTITLEMENT_TEST_ID = 'add-feature-entitlement'
export const FEATURE_ENTITLEMENT_SELECTOR_TEST_ID = 'feature-entitlement-selector'

gql`
  fragment FeatureEntitlementForPlan on Plan {
    entitlements {
      code
      name
      privileges {
        ...FeatureEntitlementPrivilegeForPlan
      }
    }
  }

  query getFeaturesListForPlanSection($limit: Int, $page: Int, $searchTerm: String) {
    features(limit: $limit, page: $page, searchTerm: $searchTerm) {
      collection {
        id
        name
        code
        ...FeatureObjectEntitlementPrivilegeForPlan
      }
    }
  }

  ${FeatureEntitlementPrivilegeForPlanFragmentDoc}
  ${FeatureObjectEntitlementPrivilegeForPlanFragmentDoc}
`

interface FeatureEntitlementSectionProps {
  form: PlanFormType
  isEdition?: boolean
}

export const FeatureEntitlementSection: FC<FeatureEntitlementSectionProps> = ({ form }) => {
  const { translate } = useInternationalization()
  const featureEntitlementDrawerRef = useRef<FeatureEntitlementDrawerRef>(null)

  const entitlements = useStore(form.store, (s) => s.values.entitlements)

  const handleDrawerSave = (values: FeatureEntitlementFormValues) => {
    form.setFieldValue(
      'entitlements',
      upsertEntitlement(form.state.values.entitlements, {
        featureId: values.featureId,
        featureName: values.featureName,
        featureCode: values.featureCode,
        privileges: values.privileges,
      }),
    )
  }

  return (
    <CenteredPage.PageSection>
      <CenteredPage.PageSectionTitle
        title={translate('text_63e26d8308d03687188221a6')}
        description={translate('text_17538642230602p03937fj0f')}
      />

      {!!entitlements?.length && (
        <div className="flex w-full flex-col gap-4">
          {entitlements.map((entitlement) => {
            const openFeatureEntitlementDrawer = () => {
              featureEntitlementDrawerRef.current?.openDrawer({
                featureId: entitlement.featureId || '',
                featureName: entitlement.featureName,
                featureCode: entitlement.featureCode,
                privileges: entitlement.privileges || [],
              })
            }

            return (
              <Selector
                key={`feature-entitlement-${entitlement.featureCode}`}
                icon="switch"
                title={entitlement.featureName || entitlement.featureCode}
                subtitle={entitlement.featureCode}
                data-test={FEATURE_ENTITLEMENT_SELECTOR_TEST_ID}
                endContent={
                  <Button icon="chevron-right-filled" variant="quaternary" tabIndex={-1} />
                }
                hoverActions={
                  <SelectorActions
                    actions={[
                      {
                        icon: 'trash',
                        tooltipCopy: translate('text_63aa085d28b8510cd46443ff'),
                        onClick: () => {
                          form.setFieldValue(
                            'entitlements',
                            removeEntitlementByFeatureCode(
                              form.state.values.entitlements,
                              entitlement.featureCode,
                            ),
                          )
                        },
                      },
                      {
                        icon: 'pen',
                        tooltipCopy: translate('text_63e51ef4985f0ebd75c212fc'),
                        onClick: () => openFeatureEntitlementDrawer(),
                      },
                    ]}
                  />
                }
                onClick={() => openFeatureEntitlementDrawer()}
              />
            )
          })}
        </div>
      )}

      <Button
        fitContent
        variant="inline"
        startIcon="plus"
        data-test={ADD_FEATURE_ENTITLEMENT_TEST_ID}
        onClick={() => featureEntitlementDrawerRef.current?.openDrawer()}
      >
        {translate('text_1753864223060devvklm7vk0')}
      </Button>

      <FeatureEntitlementDrawer
        ref={featureEntitlementDrawerRef}
        existingFeatureCodes={entitlements?.map((e) => e.featureCode) || []}
        onSave={handleDrawerSave}
        onDelete={(featureCode) => {
          form.setFieldValue(
            'entitlements',
            removeEntitlementByFeatureCode(form.state.values.entitlements, featureCode),
          )
        }}
      />
    </CenteredPage.PageSection>
  )
}

FeatureEntitlementSection.displayName = 'FeatureEntitlementSection'
