import { useFormDrawer } from '~/components/drawers/useDrawer'
import { focusFirstInput } from '~/components/drawers/useFocusTrap'
import { PlanSettingsSection } from '~/components/plans/PlanSettingsSection'
import { FORM_TYPE_ENUM } from '~/core/constants/form'
import { PlanDetailsV2Fragment } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import {
  buildUpdatePlanFormDefaults,
  useUpdatePlanWithCascade,
} from '~/hooks/plans/useUpdatePlanWithCascade'
import { useUpdateSubscriptionPlanOverride } from '~/hooks/plans/useUpdateSubscriptionPlanOverride'

const PLAN_SETTINGS_FORM_ID = 'plan-settings-drawer-form'

export const usePlanSettingsDrawer = (plan: PlanDetailsV2Fragment, subscriptionId?: string) => {
  const { translate } = useInternationalization()
  const drawer = useFormDrawer()

  // ISO with the plan form: plan-level settings lock once the plan has
  // subscriptions. Sub mode keeps its own gating (isInSubscriptionForm +
  // subscriptionFormType), so the subscription-count lock does not apply there.
  const canBeEdited = subscriptionId ? true : !plan.subscriptionsCount

  const { updatePlanOverride } = useUpdateSubscriptionPlanOverride({
    subscriptionId: subscriptionId ?? '',
  })

  // Sub mode: route the editable settings (name + description + taxes - the
  // PlanOverridesInput-backed fields not already disabled) through
  // updateSubscription(planOverrides); never call updatePlan, which would
  // mutate the shared base plan (R3). Running it via the form's onSubmit
  // (submitOverride) keeps `isSubmitting` accurate so the save button spins.
  // Plan mode keeps the cascade submit.
  const { form, submit } = useUpdatePlanWithCascade({
    plan,
    onSuccess() {
      drawer.close()
    },
    submitOverride: subscriptionId
      ? (value) =>
          updatePlanOverride({
            name: value.name,
            description: value.description || null,
            taxCodes: value.taxes?.map((tax) => tax.code) ?? [],
          })
      : undefined,
  })

  const openDrawer = () => {
    form.reset(buildUpdatePlanFormDefaults(plan), { keepDefaultValues: true })

    // Sub mode submits through the form (submitOverride); plan mode keeps the
    // cascade-aware submit(). Both flip `isSubmitting`, driving the spinner.
    const submitForm = () => {
      if (subscriptionId) {
        form.handleSubmit()
      } else {
        submit()
      }
    }

    drawer.open({
      title: translate('text_642d5eb2783a2ad10d67031a'),
      form: { id: PLAN_SETTINGS_FORM_ID, submit: submitForm },
      closeOnSubmitSuccess: false,
      onEntered: focusFirstInput,
      mainAction: (
        <form.AppForm>
          <form.SubmitButton dataTest="plan-settings-drawer-save">
            {translate('text_17295436903260tlyb1gp1i7')}
          </form.SubmitButton>
        </form.AppForm>
      ),
      children: (
        <PlanSettingsSection
          form={form}
          canBeEdited={canBeEdited}
          isEdition
          isInSubscriptionForm={!!subscriptionId}
          subscriptionFormType={subscriptionId ? FORM_TYPE_ENUM.edition : undefined}
        />
      ),
    })
  }

  return { openDrawer }
}
