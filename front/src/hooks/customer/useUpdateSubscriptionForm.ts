import { revalidateLogic } from '@tanstack/react-form'
import { DateTime } from 'luxon'
import { useRef } from 'react'

import {
  buildSubscriptionDefaultValues,
  SubscriptionDefaultsSource,
} from '~/components/subscriptions/form/buildSubscriptionDefaultValues'
import { addToast } from '~/core/apolloClient'
import { FORM_TYPE_ENUM } from '~/core/constants/form'
import { getTimezoneConfig } from '~/core/timezone'
import {
  subscriptionFormSchema,
  SubscriptionFormValues,
} from '~/formValidation/subscriptionFormSchema'
import {
  LagoApiError,
  TimezoneEnum,
  UpdateSubscriptionInput,
  useUpdateSubscriptionMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

// Shared options for the per-section subscription edit hooks. Each section
// (information, invoicing & payments, ...) is a thin wrapper that only supplies
// `buildInput`; everything else (mutation, toast, form lifecycle) lives here.
export type SubscriptionUpdateFormOptions = {
  subscription: SubscriptionDefaultsSource
  onSuccess?: () => void
}

type UseUpdateSubscriptionFormOptions = SubscriptionUpdateFormOptions & {
  // Maps the edited form values to the subset of UpdateSubscriptionInput the
  // calling section owns.
  buildInput: (value: SubscriptionFormValues) => UpdateSubscriptionInput
}

export const useUpdateSubscriptionForm = ({
  subscription,
  buildInput,
  onSuccess,
}: UseUpdateSubscriptionFormOptions) => {
  const { translate } = useInternationalization()
  const currentDate = useRef(
    DateTime.now().setZone(getTimezoneConfig(TimezoneEnum.TzUtc).name).startOf('day').toISO() || '',
  )

  const [updateSubscription] = useUpdateSubscriptionMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    onCompleted({ updateSubscription: updated }) {
      if (updated) {
        addToast({ severity: 'success', message: translate('text_65118a52df984447c186962e') })
        onSuccess?.()
      }
    },
  })

  const form = useAppForm({
    defaultValues: buildSubscriptionDefaultValues(
      subscription,
      FORM_TYPE_ENUM.edition,
      currentDate.current,
    ),
    validationLogic: revalidateLogic(),
    validators: { onDynamic: subscriptionFormSchema },
    onSubmit: async ({ value }) => {
      await updateSubscription({ variables: { input: buildInput(value) } })
    },
  })

  const resetForm = () => {
    form.reset(
      buildSubscriptionDefaultValues(subscription, FORM_TYPE_ENUM.edition, currentDate.current),
      { keepDefaultValues: true },
    )
  }

  return { form, resetForm }
}
