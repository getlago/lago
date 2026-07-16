import { useState } from 'react'

import { useFormDrawer } from '~/components/drawers/useDrawer'
import { focusFirstInput } from '~/components/drawers/useFocusTrap'
import { SubscriptionInformationFormSection } from '~/components/subscriptions/form/SubscriptionInformationFormSection'
import { FORM_TYPE_ENUM } from '~/core/constants/form'
import { SubscriptionInformationSectionFragment } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useUpdateSubscriptionInformation } from '~/hooks/customer/useUpdateSubscriptionInformation'

const SUBSCRIPTION_INFORMATION_FORM_ID = 'subscription-information-drawer-form'

type SubscriptionInformationForm = ReturnType<typeof useUpdateSubscriptionInformation>['form']

// Rendered as the drawer body. It owns the show/hide toggles so that clicking
// "Add an external id" / "Add a subscription name" re-renders the fields - the
// drawer's `children` is captured once when opened, so keeping this state in the
// caller would never reach the displayed content.
const SubscriptionInformationDrawerContent = ({
  form,
  subscription,
}: {
  form: SubscriptionInformationForm
  subscription: SubscriptionInformationSectionFragment
}) => {
  const [shouldDisplaySubscriptionExternalId, setShouldDisplaySubscriptionExternalId] = useState(
    !!subscription.externalId,
  )
  const [shouldDisplaySubscriptionName, setShouldDisplaySubscriptionName] = useState(
    !!subscription.name,
  )

  return (
    <SubscriptionInformationFormSection
      form={form}
      formType={FORM_TYPE_ENUM.edition}
      subscription={subscription}
      customerTimezone={subscription.customer?.applicableTimezone}
      selectedPlanInterval={subscription.plan?.interval}
      shouldDisplaySubscriptionExternalId={shouldDisplaySubscriptionExternalId}
      setShouldDisplaySubscriptionExternalId={setShouldDisplaySubscriptionExternalId}
      shouldDisplaySubscriptionName={shouldDisplaySubscriptionName}
      setShouldDisplaySubscriptionName={setShouldDisplaySubscriptionName}
    />
  )
}

export const useSubscriptionInformationDrawer = (
  subscription: SubscriptionInformationSectionFragment,
) => {
  const { translate } = useInternationalization()
  const drawer = useFormDrawer()

  const { form, resetForm } = useUpdateSubscriptionInformation({
    subscription,
    onSuccess() {
      drawer.close()
    },
  })

  const openDrawer = () => {
    resetForm()

    drawer.open({
      title: translate('text_62d7f6178ec94cd09370e63c'),
      form: { id: SUBSCRIPTION_INFORMATION_FORM_ID, submit: form.handleSubmit },
      closeOnSubmitSuccess: false,
      onEntered: focusFirstInput,
      mainAction: (
        <form.AppForm>
          <form.SubmitButton dataTest="subscription-information-drawer-save">
            {translate('text_17295436903260tlyb1gp1i7')}
          </form.SubmitButton>
        </form.AppForm>
      ),
      children: <SubscriptionInformationDrawerContent form={form} subscription={subscription} />,
    })
  }

  return { openDrawer }
}
