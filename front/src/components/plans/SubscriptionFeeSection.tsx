import { gql } from '@apollo/client'
import { useStore } from '@tanstack/react-form'
import { useRef } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Chip } from '~/components/designSystem/Chip'
import { Selector, SelectorActions } from '~/components/designSystem/Selector'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import {
  SubscriptionFeeDrawer,
  SubscriptionFeeDrawerRef,
  SubscriptionFeeFormValues,
} from '~/components/plans/drawers/subscriptionFee/SubscriptionFeeDrawer'
import { usePlanFormContext } from '~/contexts/PlanFormContext'
import { FORM_TYPE_ENUM, getIntervalTranslationKey } from '~/core/constants/form'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { CurrencyEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { PlanFormType } from '~/hooks/plans/usePlanForm'

gql`
  fragment PlanForSubscriptionFeeSection on Plan {
    id
    amountCents
    payInAdvance
    trialPeriod
    invoiceDisplayName
  }
`

interface SubscriptionFeeSectionProps {
  form: PlanFormType
  canBeEdited?: boolean
  isInSubscriptionForm?: boolean
  subscriptionFormType?: keyof typeof FORM_TYPE_ENUM
  isEdition?: boolean
}

export const SubscriptionFeeSection = ({
  form,
  canBeEdited,
  isInSubscriptionForm,
  subscriptionFormType,
  isEdition,
}: SubscriptionFeeSectionProps) => {
  const { translate } = useInternationalization()
  const { interval, currency } = usePlanFormContext()
  const subscriptionFeeDrawerRef = useRef<SubscriptionFeeDrawerRef>(null)

  const amountCents = useStore(form.store, (s) => s.values.amountCents)
  const invoiceDisplayName = useStore(form.store, (s) => s.values.invoiceDisplayName)
  const payInAdvance = useStore(form.store, (s) => s.values.payInAdvance)
  const trialPeriod = useStore(form.store, (s) => s.values.trialPeriod)

  const openSubscriptionFeeDrawer = () => {
    subscriptionFeeDrawerRef.current?.openDrawer({
      amountCents: amountCents || '',
      payInAdvance: payInAdvance || false,
      trialPeriod: trialPeriod ?? 0,
      invoiceDisplayName: invoiceDisplayName || undefined,
    })
  }

  const handleDrawerSave = (values: SubscriptionFeeFormValues) => {
    form.setFieldValue('amountCents', values.amountCents)
    form.setFieldValue('payInAdvance', values.payInAdvance)
    form.setFieldValue('trialPeriod', values.trialPeriod)
    form.setFieldValue('invoiceDisplayName', values.invoiceDisplayName)
  }

  const selectorSubtitle = () => {
    return intlFormatNumber(Number(amountCents), {
      style: 'currency',
      currency: currency || CurrencyEnum.Usd,
    })
  }

  const selectorEndContent = () => (
    <div className="flex items-center gap-3">
      <Chip label={translate(getIntervalTranslationKey[interval])} />
      <Tooltip placement="top-end" title={translate('text_17719630334671lxunwzo7ae')}>
        <Button icon="chevron-right-filled" variant="quaternary" tabIndex={-1} />
      </Tooltip>
    </div>
  )

  const selectorHoverActions = () => (
    <SelectorActions
      actions={[
        {
          icon: 'pen',
          tooltipCopy: translate('text_63e51ef4985f0ebd75c212fc'),
          onClick: () => openSubscriptionFeeDrawer(),
        },
      ]}
    />
  )

  return (
    <CenteredPage.PageSection>
      <CenteredPage.PageSectionTitle
        title={translate('text_642d5eb2783a2ad10d670336')}
        description={translate('text_1770063200028xc3xmcvi7bw')}
      />

      <Selector
        icon="board"
        title={invoiceDisplayName || translate('text_642d5eb2783a2ad10d670336')}
        subtitle={selectorSubtitle()}
        endContent={selectorEndContent()}
        hoverActions={selectorHoverActions()}
        data-test="open-subscription-fee-drawer"
        onClick={() => openSubscriptionFeeDrawer()}
      />

      <SubscriptionFeeDrawer
        ref={subscriptionFeeDrawerRef}
        canBeEdited={canBeEdited}
        isEdition={isEdition}
        isInSubscriptionForm={isInSubscriptionForm}
        onSave={handleDrawerSave}
        subscriptionFormType={subscriptionFormType}
      />
    </CenteredPage.PageSection>
  )
}

SubscriptionFeeSection.displayName = 'SubscriptionFeeSection'
