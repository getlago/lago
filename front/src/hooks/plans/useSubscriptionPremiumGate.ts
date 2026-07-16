import { IconName } from 'lago-design-system'

import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'

// Editing a subscription's plan overrides is a premium feature (the BE override
// services are premium-gated). On the subscription plan tab a non-premium user
// still sees the (faded) sections, so every edit action must open the upsell
// modal instead of running its real handler. The modal copy mirrors the masked
// PremiumFeature banner shown at the top of the same tab.
export const useSubscriptionPremiumGate = (isInSubscriptionForm: boolean) => {
  const { isPremium } = useCurrentUser()
  const { translate } = useInternationalization()
  const premiumWarningDialog = usePremiumWarningDialog()

  const isGated = isInSubscriptionForm && !isPremium

  const openPremiumDialog = () => {
    const feature = translate('text_65118a52df984447c18694d1')

    premiumWarningDialog.open({
      title: translate('text_65118a52df984447c18694d0'),
      description: translate('text_65118a52df984447c18694da'),
      mailtoSubject: translate('text_1759493418045b173t4qhktb', { feature }),
      mailtoBody: translate('text_1759493745332hiuejhksn15', { feature }),
    })
  }

  // Wrap an action handler: gated callers get the upsell modal, everyone else
  // gets the real handler untouched.
  const gateOnClick = (handler: () => void): (() => void) => (isGated ? openPremiumDialog : handler)

  const premiumIcon: IconName | undefined = isGated ? 'sparkles' : undefined

  return { isGated, gateOnClick, premiumIcon, openPremiumDialog }
}
