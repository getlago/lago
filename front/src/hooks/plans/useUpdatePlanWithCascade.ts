import { gql } from '@apollo/client'
import { revalidateLogic } from '@tanstack/react-form'

import { useCascadeFormDialog } from '~/components/plans/details-v2/shared/useCascadeFormDialog'
import { PlanFormInput } from '~/components/plans/types'
import { deserializeAmount, serializeAmount } from '~/core/serializers/serializeAmount'
import {
  serializeEntitlements,
  serializeMinimumCommitment,
  serializeUsageThresholds,
} from '~/core/serializers/serializePlanInput'
import { planSettingsOnlyFormSchema } from '~/formValidation/planFormSchema'
import {
  CurrencyEnum,
  FeatureEntitlementPrivilegeForPlanFragmentDoc,
  PlanDetailsV2Fragment,
  TaxForPlanAndChargesInPlanFormFragmentDoc,
  TaxForPlanSettingsSectionFragmentDoc,
  UpdatePlanInput,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'
import { usePlanUpdate } from '~/hooks/plans/usePlanUpdate'
import { buildPlanSettingsValues } from '~/hooks/plans/utils'

gql`
  fragment PlanForUpdateWithCascade on Plan {
    id
    name
    code
    description
    interval
    amountCurrency
    billChargesMonthly
    billFixedChargesMonthly
    hasOverriddenPlans
    taxes {
      ...TaxForPlanSettingsSection
    }
    fixedCharges {
      id
    }
    charges {
      id
    }
    trialPeriod
    payInAdvance
    amountCents
    minimumCommitment {
      amountCents
      commitmentType
      invoiceDisplayName
      taxes {
        ...TaxForPlanAndChargesInPlanForm
      }
    }
    usageThresholds {
      id
      amountCents
      recurring
      thresholdDisplayName
    }
    entitlements {
      code
      name
      privileges {
        ...FeatureEntitlementPrivilegeForPlan
      }
    }
  }

  ${TaxForPlanSettingsSectionFragmentDoc}
  ${TaxForPlanAndChargesInPlanFormFragmentDoc}
  ${FeatureEntitlementPrivilegeForPlanFragmentDoc}
`

type UseUpdatePlanWithCascadeOptions = {
  plan: PlanDetailsV2Fragment
  onSuccess?: () => void
  includeAdvancedFields?: boolean
  // When set, the form submits through this instead of `updatePlan` (sub-tab
  // plan-settings edits route to `updateSubscription(planOverrides)`). Running
  // it inside the form's `onSubmit` keeps `form.state.isSubmitting` accurate so
  // the save button can show its loading state. Returns success.
  submitOverride?: (value: PlanFormInput) => Promise<boolean>
}

export const buildUpdatePlanFormDefaults = (plan: PlanDetailsV2Fragment): PlanFormInput => {
  const settingsDefaults = buildPlanSettingsValues(plan)
  const currency = plan.amountCurrency ?? CurrencyEnum.Usd

  return {
    ...settingsDefaults,
    // PlanSettingsSection only reads fixedCharges.length / charges.length to
    // gate the bill*Monthly switches. We seed length-only stubs and cast to
    // satisfy PlanFormInput - neither the form nor the mutation touches the
    // contents.
    fixedCharges: settingsDefaults.fixedCharges as unknown as PlanFormInput['fixedCharges'],
    charges: settingsDefaults.charges as unknown as PlanFormInput['charges'],
    amountCents: '0',
    trialPeriod: plan.trialPeriod ?? 0,
    payInAdvance: plan.payInAdvance ?? false,
    invoiceDisplayName: plan.invoiceDisplayName ?? undefined,
    minimumCommitment: plan.minimumCommitment
      ? {
          ...plan.minimumCommitment,
          amountCents: String(deserializeAmount(plan.minimumCommitment.amountCents ?? 0, currency)),
        }
      : {},
    nonRecurringUsageThresholds:
      plan.usageThresholds && plan.usageThresholds.length > 0
        ? plan.usageThresholds
            .filter(({ recurring }) => !recurring)
            .map((threshold) => ({
              ...threshold,
              amountCents: deserializeAmount(threshold.amountCents ?? 0, currency),
            }))
            .sort((a, b) => a.amountCents - b.amountCents)
        : undefined,
    recurringUsageThreshold: plan.usageThresholds
      ?.map((threshold) => ({
        ...threshold,
        amountCents: deserializeAmount(threshold.amountCents ?? 0, currency),
      }))
      .find(({ recurring }) => !!recurring),
    entitlements:
      plan.entitlements?.map(({ code, privileges, name, ...rest }) => ({
        featureName: name || '',
        featureCode: code,
        privileges: privileges.map(
          ({ code: privilegeCode, name: privilegeName, value, ...restPrivilege }) => ({
            privilegeCode,
            privilegeName,
            value: value || '',
            ...restPrivilege,
          }),
        ),
        ...rest,
      })) || [],
    cascadeUpdates: undefined,
  }
}

export const useUpdatePlanWithCascade = ({
  plan,
  onSuccess,
  includeAdvancedFields = false,
  submitOverride,
}: UseUpdatePlanWithCascadeOptions) => {
  const { translate } = useInternationalization()
  const { openCascadeDialog } = useCascadeFormDialog()

  const { update } = usePlanUpdate({
    onSuccess() {
      onSuccess?.()
    },
  })

  const form = useAppForm({
    defaultValues: buildUpdatePlanFormDefaults(plan),
    validationLogic: revalidateLogic(),
    validators: { onDynamic: planSettingsOnlyFormSchema },
    onSubmit: async ({ value }) => {
      if (submitOverride) {
        const success = await submitOverride(value)

        if (success) onSuccess?.()
        return
      }

      // Settings-only flow: charges + fixedCharges are now optional on
      // UpdatePlanInput, so omit them from the payload entirely. BE preserves
      // existing entries via partial-update semantics.
      const input: UpdatePlanInput = {
        id: plan.id,
        name: value.name,
        code: value.code,
        description: value.description || null,
        interval: value.interval,
        amountCurrency: value.amountCurrency,
        amountCents: Number(serializeAmount(value.amountCents, value.amountCurrency)),
        payInAdvance: value.payInAdvance,
        trialPeriod: Number(value.trialPeriod || 0),
        invoiceDisplayName: value.invoiceDisplayName || null,
        billChargesMonthly: value.billChargesMonthly,
        billFixedChargesMonthly: value.billFixedChargesMonthly,
        taxCodes: value.taxes?.map((tax) => tax.code) ?? [],
        cascadeUpdates: value.cascadeUpdates,
        ...(includeAdvancedFields
          ? {
              minimumCommitment: serializeMinimumCommitment(
                value.minimumCommitment,
                value.amountCurrency,
              ),
              usageThresholds: serializeUsageThresholds(
                value.nonRecurringUsageThresholds,
                value.recurringUsageThreshold,
                value.amountCurrency,
              ),
              entitlements: serializeEntitlements(value.entitlements),
            }
          : {}),
      }

      await update({ variables: { input } })
    },
  })

  const submit = async (): Promise<boolean> => {
    if (plan.hasOverriddenPlans) {
      return openCascadeDialog({
        title: translate('text_1729604107534r3hsj7i64gp'),
        mainActionLabel: translate('text_1729604107534dfyz8j53ho5'),
        hasOverriddenPlans: true,
        onConfirm: async (cascadeUpdates) => {
          form.setFieldValue('cascadeUpdates', cascadeUpdates)
          await form.handleSubmit()
        },
      })
    }

    await form.handleSubmit()
    return true
  }

  const applyAndSubmit = (mutate: () => void): Promise<boolean> => {
    form.reset(buildUpdatePlanFormDefaults(plan), { keepDefaultValues: true })
    mutate()
    return submit()
  }

  return { form, submit, applyAndSubmit }
}
