import { DateTime } from 'luxon'

import {
  ActivationRuleStatusEnum,
  ActivationRuleTypeEnum,
  CancellationReasonEnum,
  Maybe,
  StatusTypeEnum,
  SubscriptionActivationRule,
} from '~/generated/graphql'
import { TranslateFunc } from '~/hooks/core/useInternationalization'

type SubscriptionWithActivationRules = {
  activationRules?: Maybe<
    Array<Pick<SubscriptionActivationRule, 'type' | 'timeoutHours' | 'status' | 'expiresAt'>>
  >
  cancellationReason?: Maybe<CancellationReasonEnum>
  status?: Maybe<StatusTypeEnum>
}

export const getPaymentActivationRule = (subscription?: Maybe<SubscriptionWithActivationRules>) => {
  return subscription?.activationRules?.find(
    (activationRule) => activationRule.type === ActivationRuleTypeEnum.Payment,
  )
}

export const isPaymentActivationExpired = (
  subscription?: Maybe<SubscriptionWithActivationRules>,
) => {
  return (
    subscription?.cancellationReason === CancellationReasonEnum.Timeout ||
    getPaymentActivationRule(subscription)?.status === ActivationRuleStatusEnum.Expired
  )
}

export const shouldShowTimeoutField = (subscription?: Maybe<SubscriptionWithActivationRules>) => {
  return !!getPaymentActivationRule(subscription)
}

export const getTimeoutDisplayValue = (
  subscription: Maybe<SubscriptionWithActivationRules> | undefined,
  translate: TranslateFunc,
) => {
  const paymentActivationRule = getPaymentActivationRule(subscription)

  if (!paymentActivationRule) return '-'

  // An expired rule always shows "Expired" — even with a 0 ("no timeout") value,
  // since the subscription has already timed out.
  if (isPaymentActivationExpired(subscription)) {
    return translate('text_1779882021466x423uayjorq')
  }

  if (paymentActivationRule.timeoutHours === 0) {
    return translate('text_17798820214660s59bjuztra')
  }

  if (!paymentActivationRule.expiresAt) {
    return translate('text_17798820214660s59bjuztra')
  }

  const expiresAt = DateTime.fromISO(paymentActivationRule.expiresAt)

  if (!expiresAt.isValid || expiresAt <= DateTime.now()) {
    return translate('text_1779882021466x423uayjorq')
  }

  const hoursUntilExpiration = Math.ceil(expiresAt.diffNow('hours').hours)

  if (hoursUntilExpiration < 1) {
    return translate('text_1779882021466f56z1ymyt09')
  }

  return translate('text_1779882021466cfug4osir5m', {
    hours: hoursUntilExpiration,
  })
}
