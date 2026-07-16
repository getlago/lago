import { gql } from '@apollo/client'
import { revalidateLogic, useStore } from '@tanstack/react-form'
import { DateTime } from 'luxon'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { generatePath, useParams, useSearchParams } from 'react-router-dom'

import { BillingEntityFormPicker } from '~/components/billingEntity/BillingEntityFormPicker'
import { Alert } from '~/components/designSystem/Alert'
import { Avatar } from '~/components/designSystem/Avatar'
import { Button } from '~/components/designSystem/Button'
import { Selector } from '~/components/designSystem/Selector'
import { Typography } from '~/components/designSystem/Typography'
import { WarningDialog, WarningDialogRef } from '~/components/designSystem/WarningDialog'
import { BasicComboBoxData, ComboboxItem } from '~/components/form'
import { toInvoiceCustomSectionReference } from '~/components/invoceCustomFooter/utils'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { CommitmentsSection } from '~/components/plans/CommitmentsSection'
import { FixedChargesSection } from '~/components/plans/form/FixedChargesSection'
import { PlanSettingsSection } from '~/components/plans/PlanSettingsSection'
import { SubscriptionFeeSection } from '~/components/plans/SubscriptionFeeSection'
import { LocalUsageChargeInput } from '~/components/plans/types'
import { UsageChargesSection } from '~/components/plans/UsageChargesSection'
import PremiumFeature from '~/components/premium/PremiumFeature'
import { FeatureEntitlementSection } from '~/components/subscriptions/FeatureEntitlementSection'
import { buildSubscriptionDefaultValues } from '~/components/subscriptions/form/buildSubscriptionDefaultValues'
import { InvoicingSettingsSection } from '~/components/subscriptions/form/InvoicingSettingsSection'
import { PaymentSettingsSection } from '~/components/subscriptions/form/PaymentSettingsSection'
import { SubscriptionInformationFormSection } from '~/components/subscriptions/form/SubscriptionInformationFormSection'
import { ProgressiveBillingSection } from '~/components/subscriptions/ProgressiveBillingSection'
import { REDIRECTION_ORIGIN_SUBSCRIPTION_USAGE } from '~/components/subscriptions/SubscriptionUsageLifetimeGraph'
import { PlanFormProvider } from '~/contexts/PlanFormContext'
import { FORM_TYPE_ENUM } from '~/core/constants/form'
import { CustomerSubscriptionDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  CUSTOMER_DETAILS_ROUTE,
  CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE,
  PLAN_SUBSCRIPTION_DETAILS_ROUTE,
  useLocation,
  useNavigate,
} from '~/core/router'
import { serializeActivationRules } from '~/core/serializers'
import { getTimezoneConfig } from '~/core/timezone'
import { subscriptionFormSchema } from '~/formValidation/subscriptionFormSchema'
import {
  CurrencyEnum,
  FeatureFlagEnum,
  PlanInterval,
  StatusTypeEnum,
  SubscriptionForSubscriptionEditFormFragmentDoc,
  TimezoneEnum,
  useGetCustomerForCreateSubscriptionQuery,
  useGetPlansLazyQuery,
  useGetSubscriptionForCreateSubscriptionQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAddSubscription } from '~/hooks/customer/useAddSubscription'
import { useAppForm } from '~/hooks/forms/useAppform'
import { useCustomPricingUnits } from '~/hooks/plans/useCustomPricingUnits'
import { buildDefaultValues, usePlanForm } from '~/hooks/plans/usePlanForm'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useIframeConfig } from '~/hooks/useIframeConfig'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { useRedirectIncompleteSubscription } from '~/hooks/useRedirectIncompleteSubscription'
import { FormLoadingSkeleton } from '~/styles/mainObjectsForm'
import { tw } from '~/styles/utils'

gql`
  fragment AddSubscriptionPlan on Plan {
    id
    name
    code
    interval

    ...FeatureEntitlementForPlan
  }

  query getPlans($page: Int, $limit: Int, $searchTerm: String) {
    plans(page: $page, limit: $limit, searchTerm: $searchTerm) {
      collection {
        ...AddSubscriptionPlan
      }
    }
  }

  query getCustomerForCreateSubscription($id: ID!) {
    customer(id: $id) {
      id
      applicableTimezone
      name
      displayName
      externalId
      billingEntity {
        id
      }
      paymentProvider
    }
  }

  query getSubscriptionForCreateSubscription($id: ID!) {
    subscription(id: $id) {
      ...SubscriptionForSubscriptionEditForm
    }
  }

  ${SubscriptionForSubscriptionEditFormFragmentDoc}
`

const CreateSubscription = () => {
  const location = useLocation()
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const { isPremium } = useCurrentUser()
  const { translate } = useInternationalization()
  const { customerId, subscriptionId } = useParams()
  const { hasFeatureFlag, intlFormatDateTimeOrgaTZ } = useOrganizationInfos()
  const { isRunningInSalesForceIframe, isRunningInIframeContext } = useIframeConfig()

  const warningDialogRef = useRef<WarningDialogRef>(null)
  const [showCurrencyError, setShowCurrencyError] = useState<boolean>(false)

  const hasMultiEntityBilling = hasFeatureFlag(FeatureFlagEnum.MultiEntityBilling)

  const [getPlans, { loading: planLoading, data: planData }] = useGetPlansLazyQuery({
    variables: { limit: 1000 },
  })
  const { data: customerData } = useGetCustomerForCreateSubscriptionQuery({
    variables: { id: customerId as string },
  })
  const customer = customerData?.customer
  const { data: subscriptionData, loading: subscriptionLoading } =
    useGetSubscriptionForCreateSubscriptionQuery({
      variables: { id: subscriptionId as string },
      skip: !subscriptionId,
    })

  const subscription = subscriptionData?.subscription

  const GMT = getTimezoneConfig(TimezoneEnum.TzUtc).name
  const currentDateRef = useRef<string>(DateTime.now().setZone(GMT).startOf('day').toISO())
  const isInSubscriptionForm = location.pathname.includes('/subscription')

  const { onSave, formType } = useAddSubscription({ existingSubscription: subscription })

  const subscriptionForm = useAppForm({
    defaultValues: buildSubscriptionDefaultValues(
      subscription,
      formType,
      currentDateRef.current || '',
    ),
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: subscriptionFormSchema,
    },
    onSubmit: async ({ value }) => {
      const {
        activationRuleTimeoutHours,
        activationRuleType,
        invoiceCustomSection,
        ...restValues
      } = value

      const localValues = {
        ...restValues,
        activationRules: serializeActivationRules({
          activationRuleTimeoutHours,
          activationRuleType,
        }),
        invoiceCustomSection: toInvoiceCustomSectionReference(invoiceCustomSection),
      }
      const rootElement = document.getElementById('root')
      const errorsString = await onSave(
        customerId as string,
        localValues,
        planForm.state.values,
        planFormIsDirty,
        planBaselineValues,
      )

      if (errorsString === 'CurrenciesDoesNotMatch') {
        rootElement?.scrollTo({ top: 0, behavior: 'smooth' })
        return setShowCurrencyError(true)
      } else if (errorsString === 'ValueAlreadyExist') {
        rootElement?.scrollTo({ top: 0, behavior: 'smooth' })
        subscriptionForm.setFieldMeta('externalId', (prev) => ({
          ...prev,
          errorMap: {
            ...prev.errorMap,
            onSubmit: translate('text_668513bb1906740145e06abe'),
          },
        }))
      }
    },
  })

  // Reactive subscriptions for render — never read form.state.* directly in JSX
  const subscriptionPlanId = useStore(subscriptionForm.store, (s) => s.values.planId)
  const subscriptionIsDirty = useStore(subscriptionForm.store, (s) => s.isDirty)
  const subscriptionCanSubmit = useStore(subscriptionForm.store, (s) => s.canSubmit)
  const subscriptionIsSubmitting = useStore(subscriptionForm.store, (s) => s.isSubmitting)
  const subscriptionBillingEntityId = useStore(
    subscriptionForm.store,
    (s) => s.values.billingEntityId,
  )
  const isEditingSubscription = formType === FORM_TYPE_ENUM.edition

  // Default billingEntityId on first load only:
  // - edit / upgrade / downgrade flow → preserve the existing subscription's
  //   explicit entity (Decision 5.6: explicit bindings are sticky and must
  //   survive subscription mutations)
  // - pure creation flow → use the customer's current default entity
  //
  // Latched with a ref so the default fires *once* per mount. Without the
  // latch, clearing the picker would immediately re-trigger the default
  // because `subscriptionBillingEntityId` is back to falsy.
  const hasInitializedBillingEntityDefaultRef = useRef(false)

  useEffect(() => {
    if (!hasMultiEntityBilling) return
    if (hasInitializedBillingEntityDefaultRef.current) return
    if (subscriptionBillingEntityId) {
      hasInitializedBillingEntityDefaultRef.current = true
      return
    }
    const hasExistingSubscription =
      formType === FORM_TYPE_ENUM.edition || formType === FORM_TYPE_ENUM.upgradeDowngrade
    const defaultEntityId =
      (hasExistingSubscription ? subscription?.billingEntityId : null) ??
      customer?.billingEntity?.id

    if (defaultEntityId) {
      subscriptionForm.setFieldValue('billingEntityId', defaultEntityId)
      hasInitializedBillingEntityDefaultRef.current = true
    }
  }, [
    hasMultiEntityBilling,
    formType,
    subscription?.billingEntityId,
    customer?.billingEntity?.id,
    subscriptionBillingEntityId,
    subscriptionForm,
  ])

  const { form: planForm, plan } = usePlanForm({
    planIdToFetch: subscriptionPlanId,
    isUsedInSubscriptionForm: true,
  })

  const { hasAnyPricingUnitConfigured } = useCustomPricingUnits()

  // The plan's unedited baseline, rebuilt the same way the plan form is
  // initialized (usePlanFormSetup → buildDefaultValues). Diffed against the
  // edited values in useAddSubscription so a units-only fixed-charge change
  // sends a minimal planOverrides instead of cloning the whole plan.
  const planBaselineValues = useMemo(
    () =>
      buildDefaultValues(
        plan,
        FORM_TYPE_ENUM.creation,
        (plan?.amountCurrency as CurrencyEnum) || CurrencyEnum.Usd,
        hasAnyPricingUnitConfigured,
      ),
    [plan, hasAnyPricingUnitConfigured],
  )

  const alreadyExistingPlanFixedChargesIds =
    plan?.fixedCharges?.map((fixedCharge) => fixedCharge.id) || []

  const planFormIsDirty = useStore(planForm.store, (s) => s.isDirty)
  const planFormCanSubmit = useStore(planForm.store, (s) => s.canSubmit)

  // Replace enableReinitialize — reset form when subscription data changes
  const prevSubscriptionRef = useRef(subscription)

  useEffect(() => {
    if (subscription && subscription !== prevSubscriptionRef.current) {
      subscriptionForm.reset(
        buildSubscriptionDefaultValues(subscription, formType, currentDateRef.current || ''),
        { keepDefaultValues: false },
      )
      prevSubscriptionRef.current = subscription
    }
  }, [subscription, formType, subscriptionForm, currentDateRef])

  const [shouldDisplaySubscriptionExternalId, setShouldDisplaySubscriptionExternalId] =
    useState<boolean>(!!subscription?.externalId)
  const [shouldDisplaySubscriptionName, setShouldDisplaySubscriptionName] = useState<boolean>(
    !!(formType !== FORM_TYPE_ENUM.upgradeDowngrade && subscription?.name),
  )

  useEffect(() => {
    setShouldDisplaySubscriptionExternalId(!!subscription?.externalId)
  }, [subscription?.externalId])

  useEffect(() => {
    setShouldDisplaySubscriptionName(
      !!(formType !== FORM_TYPE_ENUM.upgradeDowngrade && subscription?.name),
    )
  }, [subscription?.name, formType])

  useRedirectIncompleteSubscription({
    customerId,
    subscriptionId: subscription?.id,
    subscriptionStatus: subscription?.status,
  })

  // Remove currency error is value changes
  useEffect(() => {
    setShowCurrencyError(false)
  }, [planForm.state.values.amountCurrency])

  const selectedPlan = useMemo(() => {
    if (!planData?.plans?.collection || !subscriptionPlanId) return undefined

    return (planData?.plans?.collection || []).find((p) => p.id === subscriptionPlanId)
  }, [planData?.plans?.collection, subscriptionPlanId])

  const comboboxPlansData = useMemo(() => {
    if (!planData?.plans?.collection?.length) return []

    const localPlanCollection = [...(planData?.plans?.collection || {})]

    // If sub plan is not part of the plans collection, add it
    if (!localPlanCollection.find((p) => p.id === subscription?.plan.id) && !!subscription?.plan) {
      localPlanCollection.unshift(subscription?.plan)
    }

    return localPlanCollection.reduce<BasicComboBoxData[]>((acc, { id, name, code }) => {
      // Hide parent plan
      if (formType === FORM_TYPE_ENUM.upgradeDowngrade && id === subscription?.plan?.parent?.id) {
        return acc
      }

      return [
        ...acc,
        {
          label: `${name} (${code})`,
          labelNode: (
            <ComboboxItem>
              <Typography variant="body" color="grey700" noWrap>
                {name}
              </Typography>
              <Typography variant="caption" color="grey600" noWrap>
                {code}
              </Typography>
            </ComboboxItem>
          ),
          value: id,
          disabled:
            formType === FORM_TYPE_ENUM.upgradeDowngrade &&
            !!subscription?.plan.id &&
            subscription?.plan.id === id,
        },
      ]
    }, [])
  }, [formType, planData?.plans?.collection, subscription?.plan])

  const handleFormSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    subscriptionForm.handleSubmit()
  }

  // NOTE: useCallback here is needed
  // It handles the case where the user clicks on the button while being focused on a plan's input
  const SubmitButton = useCallback(() => {
    const buttonLabel = () => {
      if (formType === FORM_TYPE_ENUM.creation) return translate('text_65118a52df984447c1869463')
      if (formType === FORM_TYPE_ENUM.edition) return translate('text_62d7f6178ec94cd09370e63c')
      return translate('text_65118a52df984447c18694c6')
    }

    return (
      <Button
        type="submit"
        disabled={
          !subscriptionCanSubmit ||
          !planFormCanSubmit ||
          (formType === FORM_TYPE_ENUM.edition && !subscriptionIsDirty && !planFormIsDirty)
        }
        loading={subscriptionIsSubmitting}
        data-test="submit"
      >
        <Typography color="inherit" noWrap>
          {buttonLabel()}
        </Typography>
      </Button>
    )
  }, [
    formType,
    planFormIsDirty,
    planFormCanSubmit,
    subscriptionIsDirty,
    subscriptionCanSubmit,
    subscriptionIsSubmitting,
    translate,
  ])

  const customerName = customer?.displayName

  const navigateBack = useCallback(() => {
    const origin = searchParams.get('origin')
    const originSubscriptionId = searchParams.get('subscriptionId')
    const originCustomerId = searchParams.get('customerId')

    if (
      origin === REDIRECTION_ORIGIN_SUBSCRIPTION_USAGE &&
      originSubscriptionId &&
      !!originCustomerId
    ) {
      navigate(
        generatePath(CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE, {
          customerId: originCustomerId,
          subscriptionId: originSubscriptionId,
          tab: CustomerSubscriptionDetailsTabsOptionsEnum.usage,
        }),
      )
    } else if (
      origin === REDIRECTION_ORIGIN_SUBSCRIPTION_USAGE &&
      !!originSubscriptionId &&
      plan?.id
    ) {
      navigate(
        generatePath(PLAN_SUBSCRIPTION_DETAILS_ROUTE, {
          planId: plan?.id,
          subscriptionId: originSubscriptionId,
          tab: CustomerSubscriptionDetailsTabsOptionsEnum.usage,
        }),
      )
    } else {
      navigate(generatePath(CUSTOMER_DETAILS_ROUTE, { customerId: customerId as string }))
    }
  }, [searchParams, navigate, plan?.id, customerId])

  const handleClose = useCallback(() => {
    if (subscriptionIsDirty || planFormIsDirty) {
      warningDialogRef.current?.openDialog()
    } else {
      navigateBack()
    }
  }, [subscriptionIsDirty, planFormIsDirty, navigateBack])

  const pageHeaderTitle = useMemo(() => {
    if (formType === FORM_TYPE_ENUM.edition) {
      return translate('text_62d7f6178ec94cd09370e63c')
    } else if (formType === FORM_TYPE_ENUM.upgradeDowngrade) {
      return translate('text_65118a52df984447c18694c6')
    }
    return translate('text_17761091520516p9xpb0v574')
  }, [formType, translate])

  return (
    <>
      <form className="contents" onSubmit={handleFormSubmit}>
        <CenteredPage.Wrapper>
          <CenteredPage.Header>
            <Typography variant="bodyHl" color="textSecondary" noWrap>
              {pageHeaderTitle}
            </Typography>
            {!isRunningInSalesForceIframe && !isRunningInIframeContext && (
              <Button
                variant="quaternary"
                icon="close"
                onClick={handleClose}
                data-test="close-create-subscription-button"
              />
            )}
          </CenteredPage.Header>

          <CenteredPage.Container>
            {!!subscriptionLoading && formType === FORM_TYPE_ENUM.edition ? (
              <FormLoadingSkeleton id="create-subscription" length={3} />
            ) : (
              <>
                <CenteredPage.PageTitle
                  title={pageHeaderTitle}
                  description={translate('text_1776109152051su5xz1qh1xj')}
                />

                <CenteredPage.SubsectionWrapper>
                  {/* Section: Assign a plan */}
                  <CenteredPage.PageSection>
                    {formType !== FORM_TYPE_ENUM.edition && (
                      <CenteredPage.PageSectionTitle
                        title={translate('text_65118a52df984447c186940f', {
                          customerName: customerName || customer?.externalId || '',
                        })}
                        description={translate('text_65118a52df984447c1869469')}
                      />
                    )}

                    <Selector
                      icon={<Avatar size="big" variant="user" identifier={customerName || ''} />}
                      title={customerName || ''}
                      subtitle={customer?.externalId}
                    />

                    <subscriptionForm.AppField name="planId">
                      {(field) => (
                        <field.ComboBoxField
                          disabled={formType === FORM_TYPE_ENUM.edition}
                          disableClearable={formType === FORM_TYPE_ENUM.edition}
                          label={translate('text_625434c7bb2cb40124c81a29')}
                          data={comboboxPlansData}
                          loading={planLoading}
                          searchQuery={getPlans}
                          placeholder={translate('text_625434c7bb2cb40124c81a31')}
                          emptyText={translate('text_625434c7bb2cb40124c81a37')}
                          PopperProps={{ displayInDialog: true }}
                        />
                      )}
                    </subscriptionForm.AppField>

                    {!!subscriptionPlanId && (
                      <BillingEntityFormPicker
                        label={translate('text_1743611497157teaa1zu8l24')}
                        value={subscriptionBillingEntityId}
                        onChange={(id) => subscriptionForm.setFieldValue('billingEntityId', id)}
                        helperText={translate(
                          isEditingSubscription
                            ? 'text_1779457001221h9zixqumknp'
                            : 'text_17800541562349k15h7ik07c',
                        )}
                      />
                    )}

                    {!!showCurrencyError ? (
                      <Alert type="danger">{translate('text_632dbaf1d577afb32ae751f5')}</Alert>
                    ) : (
                      <>
                        {formType === FORM_TYPE_ENUM.upgradeDowngrade && (
                          <Alert type="info">
                            {translate('text_6328e70de459381ed4ba50d6', {
                              subscriptionEndDate: subscription?.periodEndDate
                                ? intlFormatDateTimeOrgaTZ(subscription.periodEndDate).date
                                : '-',
                            })}
                          </Alert>
                        )}
                        {subscription?.status === StatusTypeEnum.Pending && (
                          <Alert type="info">
                            {translate('text_6335e50b0b089e1d8ed508da', {
                              subscriptionAt: subscription?.startedAt
                                ? intlFormatDateTimeOrgaTZ(subscription.startedAt).date
                                : '-',
                            })}
                          </Alert>
                        )}
                      </>
                    )}
                  </CenteredPage.PageSection>

                  {!!subscriptionPlanId && (
                    <>
                      {/* Section: Subscription settings */}
                      <SubscriptionInformationFormSection
                        form={subscriptionForm}
                        formType={formType}
                        subscription={subscription}
                        customerTimezone={customer?.applicableTimezone}
                        shouldDisplaySubscriptionExternalId={shouldDisplaySubscriptionExternalId}
                        setShouldDisplaySubscriptionExternalId={
                          setShouldDisplaySubscriptionExternalId
                        }
                        shouldDisplaySubscriptionName={shouldDisplaySubscriptionName}
                        setShouldDisplaySubscriptionName={setShouldDisplaySubscriptionName}
                        selectedPlanInterval={selectedPlan?.interval}
                        customerExternalId={customer?.externalId}
                      />

                      {/* Section: Payments */}
                      <CenteredPage.PageSection>
                        <CenteredPage.PageSectionTitle
                          title={translate('text_17828013737948943pe3k8nc')}
                          description={translate('text_17828013737955532qxu3wq4')}
                        />

                        {/* Payment method lives in a drawer */}
                        <PaymentSettingsSection
                          form={subscriptionForm}
                          externalCustomerId={customer?.externalId ?? ''}
                        />
                      </CenteredPage.PageSection>

                      {/* Section: Invoicing */}
                      <CenteredPage.PageSection>
                        <CenteredPage.PageSectionTitle
                          title={translate('text_17423672025282dl7iozy1ru')}
                          description={translate('text_1782738644346p066xtwa8yj')}
                        />

                        {/* Invoice consolidation + custom sections live in a drawer */}
                        <InvoicingSettingsSection
                          form={subscriptionForm}
                          customerId={customer?.id}
                        />
                      </CenteredPage.PageSection>
                    </>
                  )}
                </CenteredPage.SubsectionWrapper>

                {!!subscriptionPlanId && (
                  <>
                    {/* Premium "Override plan" full-width divider */}
                    <div className="relative mb-8 mt-20 flex flex-col items-center gap-3">
                      <div className="absolute left-1/2 top-0 h-[2px] w-[100vw] -translate-x-1/2 bg-purple-100" />
                      <div className="rounded-b bg-purple-100 px-4 py-1">
                        <Typography variant="captionHl" color="info600">
                          {translate('text_65118a52df984447c18694d1')}
                        </Typography>
                      </div>
                    </div>

                    {/* Premium upsell (non-premium users) */}
                    {!isPremium && (
                      <PremiumFeature
                        feature={translate('text_65118a52df984447c18694d1')}
                        title={translate('text_65118a52df984447c18694d0')}
                        description={translate('text_65118a52df984447c18694da')}
                      />
                    )}

                    {/* Premium-gated plan override sections */}
                    <div
                      className={tw(
                        'flex flex-col',
                        !isPremium &&
                          '[mask-image:linear-gradient(to_bottom,black_0%,transparent_100%)]',
                      )}
                      {...(!isPremium && { inert: '' })}
                    >
                      <CenteredPage.SubsectionWrapper>
                        <PlanSettingsSection
                          form={planForm}
                          isInSubscriptionForm={isInSubscriptionForm}
                          subscriptionFormType={formType}
                        />

                        {isPremium && (
                          <PlanFormProvider
                            currency={planForm.state.values.amountCurrency || CurrencyEnum.Usd}
                            interval={planForm.state.values.interval || PlanInterval.Monthly}
                          >
                            <div className="flex flex-col gap-12">
                              <CenteredPage.PageTitle
                                title={translate('text_6661fc17337de3591e29e3e7')}
                                description={translate('text_66630368f4333b00795b0e2d')}
                              />

                              <CenteredPage.SubsectionWrapper>
                                <SubscriptionFeeSection
                                  form={planForm}
                                  isInSubscriptionForm={isInSubscriptionForm}
                                  subscriptionFormType={formType}
                                />

                                <FixedChargesSection
                                  alreadyExistingFixedChargesIds={
                                    alreadyExistingPlanFixedChargesIds
                                  }
                                  canBeEdited={formType === FORM_TYPE_ENUM.edition}
                                  form={planForm}
                                  isEdition={formType === FORM_TYPE_ENUM.edition}
                                  isInSubscriptionForm={isInSubscriptionForm}
                                />

                                <UsageChargesSection
                                  alreadyExistingCharges={plan?.charges as LocalUsageChargeInput[]}
                                  form={planForm}
                                  isEdition={formType === FORM_TYPE_ENUM.edition}
                                  isInSubscriptionForm={isInSubscriptionForm}
                                  subscriptionFormType={formType}
                                />
                              </CenteredPage.SubsectionWrapper>
                            </div>

                            <div className="flex flex-col gap-12">
                              <CenteredPage.PageTitle
                                title={translate('text_6661fc17337de3591e29e44d')}
                                description={translate('text_66676ed0d8c3d481637e99b7')}
                              />

                              <CenteredPage.SubsectionWrapper>
                                <CommitmentsSection form={planForm} />

                                {formType === FORM_TYPE_ENUM.creation && (
                                  <>
                                    <ProgressiveBillingSection />
                                    <FeatureEntitlementSection />
                                  </>
                                )}
                              </CenteredPage.SubsectionWrapper>
                            </div>
                          </PlanFormProvider>
                        )}
                      </CenteredPage.SubsectionWrapper>
                    </div>
                  </>
                )}
              </>
            )}
          </CenteredPage.Container>

          <CenteredPage.StickyFooter>
            <Button variant="quaternary" onClick={handleClose}>
              {translate('text_6411e6b530cb47007488b027')}
            </Button>
            <SubmitButton />
          </CenteredPage.StickyFooter>
        </CenteredPage.Wrapper>
      </form>

      <WarningDialog
        ref={warningDialogRef}
        title={translate('text_65118a52df984447c18694ee')}
        description={translate('text_65118a52df984447c18694fe')}
        continueText={translate('text_645388d5bdbd7b00abffa033')}
        onContinue={() => navigateBack()}
      />
    </>
  )
}

export default CreateSubscription
