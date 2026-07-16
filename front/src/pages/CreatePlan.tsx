import { gql } from '@apollo/client'
import { useStore } from '@tanstack/react-form'
import { useCallback, useRef } from 'react'
import { generatePath, useSearchParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { WarningDialog, WarningDialogRef } from '~/components/designSystem/WarningDialog'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { CommitmentsSection } from '~/components/plans/CommitmentsSection'
import { useCascadeFormDialog } from '~/components/plans/details-v2/shared/useCascadeFormDialog'
import { FeatureEntitlementSection } from '~/components/plans/FeatureEntitlementSection'
import { FixedChargesSection } from '~/components/plans/form/FixedChargesSection'
import { PlanSettingsSection } from '~/components/plans/PlanSettingsSection'
import { ProgressiveBillingSection } from '~/components/plans/ProgressiveBillingSection'
import { SubscriptionFeeSection } from '~/components/plans/SubscriptionFeeSection'
import { LocalUsageChargeInput } from '~/components/plans/types'
import { UsageChargesSection } from '~/components/plans/UsageChargesSection'
import { REDIRECTION_ORIGIN_SUBSCRIPTION_USAGE } from '~/components/subscriptions/SubscriptionUsageLifetimeGraph'
import { PlanFormProvider } from '~/contexts/PlanFormContext'
import { useDuplicatePlanVar } from '~/core/apolloClient'
import { FORM_TYPE_ENUM } from '~/core/constants/form'
import {
  CustomerSubscriptionDetailsTabsOptionsEnum,
  PlanDetailsTabsOptionsEnum,
} from '~/core/constants/tabsOptions'
import {
  CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE,
  PLAN_DETAILS_ROUTE,
  PLAN_SUBSCRIPTION_DETAILS_ROUTE,
  PLANS_ROUTE,
  useNavigate,
} from '~/core/router'
import {
  CurrencyEnum,
  FeatureEntitlementForPlanFragmentDoc,
  FixedChargesOnPlanFormFragmentDoc,
  PlanForSettingsSectionFragmentDoc,
  PlanForSubscriptionFeeSectionFragmentDoc,
  PlanForUsageChargeAccordionFragmentDoc,
  PlanInterval,
  UsageChargeForDrawerFragmentDoc,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { usePlanForm } from '~/hooks/plans/usePlanForm'
import { FormLoadingSkeleton } from '~/styles/mainObjectsForm'

gql`
  fragment TaxForPlanAndChargesInPlanForm on Tax {
    id
    code
    name
    rate
  }

  fragment BillableMetricForPlan on BillableMetric {
    id
    name
    code
    aggregationType
    recurring
    filters {
      id
      key
      values
    }
  }

  fragment EditPlan on Plan {
    id
    name
    code
    description
    interval
    payInAdvance
    invoiceDisplayName
    amountCents
    amountCurrency
    trialPeriod
    subscriptionsCount
    billChargesMonthly
    hasOverriddenPlans
    minimumCommitment {
      amountCents
      commitmentType
      invoiceDisplayName
      taxes {
        id
        ...TaxForPlanAndChargesInPlanForm
      }
    }
    taxes {
      ...TaxForPlanAndChargesInPlanForm
    }
    charges {
      id
      minAmountCents
      payInAdvance
      chargeModel
      appliedPricingUnit {
        conversionRate
        pricingUnit {
          id
          code
          name
          shortName
        }
      }
      taxes {
        ...TaxForPlanAndChargesInPlanForm
      }
      billableMetric {
        id
        code
        ...BillableMetricForPlan
      }

      ...UsageChargeForDrawer
    }

    usageThresholds {
      id
      amountCents
      recurring
      thresholdDisplayName
    }

    ...PlanForUsageChargeAccordion
    ...PlanForSettingsSection
    ...PlanForSubscriptionFeeSection
    ...FeatureEntitlementForPlan
    ...FixedChargesOnPlanForm
  }

  ${UsageChargeForDrawerFragmentDoc}
  ${PlanForUsageChargeAccordionFragmentDoc}
  ${PlanForSettingsSectionFragmentDoc}
  ${PlanForSubscriptionFeeSectionFragmentDoc}
  ${FeatureEntitlementForPlanFragmentDoc}
  ${FixedChargesOnPlanFormFragmentDoc}
`

const CreatePlan = () => {
  const navigate = useNavigate()
  const { translate } = useInternationalization()
  const { type: actionType } = useDuplicatePlanVar()
  const [searchParams] = useSearchParams()
  const { form, isEdition, loading, plan, type } = usePlanForm({})
  const warningDialogRef = useRef<WarningDialogRef>(null)
  const { openCascadeDialog } = useCascadeFormDialog()

  const canBeEdited = !plan?.subscriptionsCount
  const alreadyExistingFixedChargesIds =
    plan?.fixedCharges?.map((fixedCharge) => fixedCharge.id) || []

  // Use useStore for reactive state reads in render
  const isDirty = useStore(form.store, (s) => s.isDirty)
  const amountCurrency = useStore(form.store, (s) => s.values.amountCurrency)
  const interval = useStore(form.store, (s) => s.values.interval)

  const planCloseRedirection = useCallback(() => {
    const origin = searchParams.get('origin')
    const originSubscriptionId = searchParams.get('subscriptionId')
    const originCustomerId = searchParams.get('customerId')

    if (origin === REDIRECTION_ORIGIN_SUBSCRIPTION_USAGE && originSubscriptionId && plan?.id) {
      if (!!originCustomerId) {
        navigate(
          generatePath(CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE, {
            customerId: originCustomerId,
            subscriptionId: originSubscriptionId,
            tab: CustomerSubscriptionDetailsTabsOptionsEnum.usage,
          }),
        )
      } else {
        navigate(
          generatePath(PLAN_SUBSCRIPTION_DETAILS_ROUTE, {
            planId: plan?.id,
            subscriptionId: originSubscriptionId,
            tab: CustomerSubscriptionDetailsTabsOptionsEnum.usage,
          }),
        )
      }
    } else if (plan?.id && actionType !== FORM_TYPE_ENUM.duplicate) {
      navigate(
        generatePath(PLAN_DETAILS_ROUTE, {
          planId: plan.id,
          tab: PlanDetailsTabsOptionsEnum.overview,
        }),
      )
    } else {
      navigate(PLANS_ROUTE)
    }
  }, [navigate, plan?.id, searchParams, actionType])

  const onLeave = useCallback(() => {
    if (isDirty) {
      return warningDialogRef.current?.openDialog()
    }

    return planCloseRedirection()
  }, [isDirty, planCloseRedirection])

  const handleFormSubmit = useCallback(() => {
    if (isEdition && plan?.hasOverriddenPlans) {
      return openCascadeDialog({
        title: translate('text_1729604107534r3hsj7i64gp'),
        mainActionLabel: translate('text_1729604107534dfyz8j53ho5'),
        hasOverriddenPlans: true,
        onConfirm: async (cascadeUpdates) => {
          form.setFieldValue('cascadeUpdates', cascadeUpdates)
          return form.handleSubmit()
        },
      })
    }

    return form.handleSubmit()
  }, [form, plan?.hasOverriddenPlans, isEdition, openCascadeDialog, translate])

  const pageTitle = isEdition
    ? translate('text_625fd165963a7b00c8f59767')
    : translate('text_624453d52e945301380e4988')

  return (
    <PlanFormProvider
      currency={amountCurrency || CurrencyEnum.Usd}
      interval={interval || PlanInterval.Monthly}
    >
      <form
        className="contents"
        onSubmit={(e) => {
          e.preventDefault()
          handleFormSubmit()
        }}
      >
        <CenteredPage.Wrapper>
          <CenteredPage.Header>
            <Typography variant="bodyHl" color="textSecondary" noWrap>
              {pageTitle}
            </Typography>
            <Button
              variant="quaternary"
              icon="close"
              onClick={onLeave}
              data-test="close-create-plan-button"
            />
          </CenteredPage.Header>

          <CenteredPage.Container className="gap-20">
            {loading && <FormLoadingSkeleton id="create-plan" />}
            {!loading && (
              <>
                <CenteredPage.SectionWrapper>
                  <CenteredPage.PageTitle
                    title={pageTitle}
                    description={translate('text_1770063200028ww5znt6yree')}
                  />

                  <PlanSettingsSection
                    form={form}
                    canBeEdited={canBeEdited}
                    isEdition={isEdition}
                  />
                </CenteredPage.SectionWrapper>

                <CenteredPage.SectionWrapper>
                  <CenteredPage.PageTitle
                    title={translate('text_6661fc17337de3591e29e3e7')}
                    description={translate('text_6661fc17337de3591e29e3e9')}
                  />

                  <CenteredPage.SubsectionWrapper>
                    <SubscriptionFeeSection
                      form={form}
                      canBeEdited={canBeEdited}
                      isEdition={isEdition}
                    />

                    <FixedChargesSection
                      form={form}
                      alreadyExistingFixedChargesIds={alreadyExistingFixedChargesIds}
                      canBeEdited={canBeEdited}
                      isEdition={isEdition}
                    />

                    <UsageChargesSection
                      form={form}
                      canBeEdited={canBeEdited}
                      isEdition={isEdition}
                      alreadyExistingCharges={plan?.charges as LocalUsageChargeInput[]}
                    />
                  </CenteredPage.SubsectionWrapper>
                </CenteredPage.SectionWrapper>

                <CenteredPage.SectionWrapper>
                  <CenteredPage.PageTitle
                    title={translate('text_6661fc17337de3591e29e44d')}
                    description={translate('text_6667029c1051a60107146e35')}
                  />

                  <CenteredPage.SubsectionWrapper>
                    <ProgressiveBillingSection form={form} />

                    <CommitmentsSection form={form} />

                    <FeatureEntitlementSection form={form} isEdition={isEdition} />
                  </CenteredPage.SubsectionWrapper>
                </CenteredPage.SectionWrapper>
              </>
            )}
          </CenteredPage.Container>

          {(!loading || plan) && (
            <CenteredPage.StickyFooter>
              <Button variant="quaternary" onClick={onLeave}>
                {translate('text_6411e6b530cb47007488b027')}
              </Button>
              <form.Subscribe
                selector={(s) => ({
                  canSubmit: s.canSubmit,
                  isSubmitting: s.isSubmitting,
                })}
              >
                {({ canSubmit, isSubmitting }) => (
                  <Button
                    type="submit"
                    disabled={!canSubmit || (isEdition && !isDirty)}
                    loading={isSubmitting}
                    onClick={() => handleFormSubmit()}
                    data-test="submit"
                  >
                    {translate(
                      type === FORM_TYPE_ENUM.edition
                        ? 'text_6661fc17337de3591e29e461'
                        : 'text_6661ffe746c680007e2df0e2',
                    )}
                  </Button>
                )}
              </form.Subscribe>
            </CenteredPage.StickyFooter>
          )}
        </CenteredPage.Wrapper>
      </form>

      <WarningDialog
        ref={warningDialogRef}
        title={translate('text_665deda4babaf700d603ea13')}
        description={translate('text_665dedd557dc3c00c62eb83d')}
        continueText={translate('text_645388d5bdbd7b00abffa033')}
        onContinue={() => planCloseRedirection()}
      />
    </PlanFormProvider>
  )
}

export default CreatePlan
