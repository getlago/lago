import {
  ActivationRuleFormTypeEnum,
  DEFAULT_PAYMENT_ACTIVATION_RULE_TIMEOUT_HOURS,
} from '~/core/constants/subscriptionActivationRules'
import {
  ActivationRuleTypeEnum,
  Maybe,
  SubscriptionActivationRule,
  SubscriptionActivationRuleInput,
} from '~/generated/graphql'

type ActivationRuleFormValues = {
  activationRuleType?: ActivationRuleFormTypeEnum
  activationRuleTimeoutHours?: string | number | null
}

type ActivationRuleSource = Maybe<Array<Pick<SubscriptionActivationRule, 'type' | 'timeoutHours'>>>

export const serializeActivationRules = ({
  activationRuleType,
  activationRuleTimeoutHours,
}: ActivationRuleFormValues): SubscriptionActivationRuleInput[] => {
  if (activationRuleType !== ActivationRuleFormTypeEnum.OnPayment) return []

  // An empty timeout means "no timeout": omit `timeoutHours` entirely (the BE expects
  // the field to be absent, not null).
  const hasTimeoutValue =
    activationRuleTimeoutHours !== undefined &&
    activationRuleTimeoutHours !== null &&
    activationRuleTimeoutHours !== ''

  const parsedTimeoutHours = Number(activationRuleTimeoutHours)

  return [
    {
      type: ActivationRuleTypeEnum.Payment,
      ...(hasTimeoutValue &&
        Number.isFinite(parsedTimeoutHours) && { timeoutHours: parsedTimeoutHours }),
    },
  ]
}

export const deserializeActivationRules = (activationRules?: ActivationRuleSource) => {
  const paymentActivationRule = activationRules?.find(
    (activationRule) => activationRule.type === ActivationRuleTypeEnum.Payment,
  )

  if (!paymentActivationRule) {
    return {
      activationRuleType: ActivationRuleFormTypeEnum.Immediately,
      activationRuleTimeoutHours: DEFAULT_PAYMENT_ACTIVATION_RULE_TIMEOUT_HOURS,
    }
  }

  return {
    activationRuleType: ActivationRuleFormTypeEnum.OnPayment,
    // A null timeout means "no timeout" on the BE — reflect it as an empty field.
    activationRuleTimeoutHours:
      paymentActivationRule.timeoutHours === null ||
      paymentActivationRule.timeoutHours === undefined
        ? ''
        : String(paymentActivationRule.timeoutHours),
  }
}
