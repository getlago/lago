import { DateTime } from 'luxon'

import {
  SubscriptionUpdateFormOptions,
  useUpdateSubscriptionForm,
} from '~/hooks/customer/useUpdateSubscriptionForm'

export const useUpdateSubscriptionInformation = ({
  subscription,
  onSuccess,
}: SubscriptionUpdateFormOptions) =>
  useUpdateSubscriptionForm({
    subscription,
    onSuccess,
    buildInput: (value) => ({
      id: subscription?.id ?? '',
      // Clearable field: send `null` (not `undefined`) when emptied so the BE
      // actually clears it - `undefined` gets stripped from the payload and the
      // old name persists after save.
      name: value.name || null,
      subscriptionAt: DateTime.fromISO(value.subscriptionAt).toUTC().toISO(),
      endingAt: value.endingAt ? DateTime.fromISO(value.endingAt).toUTC().toISO() : null,
    }),
  })
