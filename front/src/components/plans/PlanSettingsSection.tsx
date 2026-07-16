import { gql } from '@apollo/client'
import { useStore } from '@tanstack/react-form'
import { useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Tooltip } from '~/components/designSystem/Tooltip'
import NameAndCodeGroup from '~/components/form/NameAndCodeGroup/NameAndCodeGroup'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { TaxesSelectorSection } from '~/components/taxes/TaxesSelectorSection'
import {
  FORM_TYPE_ENUM,
  getIntervalTranslationKey,
  SEARCH_TAX_INPUT_FOR_PLAN_CLASSNAME,
} from '~/core/constants/form'
import { CurrencyEnum, PlanInterval } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { PlanFormType } from '~/hooks/plans/usePlanForm'

export const PLAN_SETTINGS_REMOVE_DESCRIPTION_TEST_ID = 'remove-description'

gql`
  fragment TaxForPlanSettingsSection on Tax {
    id
    code
    name
    rate
  }

  fragment PlanForSettingsSection on Plan {
    id
    amountCurrency
    code
    description
    interval
    name
    taxes {
      ...TaxForPlanSettingsSection
    }
  }

  query getTaxesForPlan($limit: Int, $page: Int, $searchTerm: String) {
    taxes(limit: $limit, page: $page, searchTerm: $searchTerm) {
      metadata {
        currentPage
        totalPages
      }
      collection {
        id
        ...TaxForPlanSettingsSection
      }
    }
  }
`

const INTERVAL_OPTIONS = [
  PlanInterval.Weekly,
  PlanInterval.Monthly,
  PlanInterval.Quarterly,
  PlanInterval.Semiannual,
  PlanInterval.Yearly,
]

const CURRENCY_DATA = Object.values(CurrencyEnum).map((currencyType) => ({
  value: currencyType,
}))

type PlanSettingsSectionProps = {
  form: PlanFormType
  canBeEdited?: boolean
  isInSubscriptionForm?: boolean
  subscriptionFormType?: keyof typeof FORM_TYPE_ENUM
  isEdition?: boolean
}

export const PlanSettingsSection = ({
  form,
  canBeEdited,
  isInSubscriptionForm,
  subscriptionFormType,
  isEdition,
}: PlanSettingsSectionProps) => {
  const { translate } = useInternationalization()
  const description = useStore(form.store, (s) => s.values.description)
  const planInterval = useStore(form.store, (s) => s.values.interval)
  const hasAnyFixedCharge = useStore(form.store, (s) => !!s.values.fixedCharges.length)
  const hasAnyUsageCharge = useStore(form.store, (s) => !!s.values.charges.length)
  const [shouldDisplayDescription, setShouldDisplayDescription] = useState(!!description)

  const handleHideDescription = () => {
    form.setFieldValue('description', '')
    setShouldDisplayDescription(false)
  }

  const intervalOptions = INTERVAL_OPTIONS.map((interval) => ({
    label: translate(getIntervalTranslationKey[interval]),
    value: interval,
  }))
  const canApplyChargesMonthly = [PlanInterval.Semiannual, PlanInterval.Yearly].includes(
    planInterval,
  )

  return (
    <CenteredPage.PageSection>
      <CenteredPage.PageSectionTitle
        title={translate('text_642d5eb2783a2ad10d67031a')}
        description={translate('text_6661fc17337de3591e29e3c1')}
      />

      <NameAndCodeGroup
        form={form}
        fields={{ name: 'name', code: 'code' }}
        disableCodeInput={isInSubscriptionForm || (isEdition && !canBeEdited)}
        nameProps={{ autoFocus: !isInSubscriptionForm }}
        codeProps={{
          infoText: translate('text_6661fc17337de3591e29e3cd'),
        }}
      />

      {shouldDisplayDescription && (
        <div className="flex items-center">
          <form.AppField name="description">
            {(field) => (
              <field.TextInputField
                multiline
                className="mr-3 flex-1"
                label={translate('text_629728388c4d2300e2d380f1')}
                placeholder={translate('text_6661fc17337de3591e29e3c9')}
                rows="3"
              />
            )}
          </form.AppField>
          <Tooltip
            className="mt-6"
            placement="top-end"
            title={translate('text_63aa085d28b8510cd46443ff')}
          >
            <Button
              icon="trash"
              variant="quaternary"
              onClick={handleHideDescription}
              data-test={PLAN_SETTINGS_REMOVE_DESCRIPTION_TEST_ID}
            />
          </Tooltip>
        </div>
      )}
      {!shouldDisplayDescription && (
        <Button
          fitContent
          startIcon="plus"
          variant="inline"
          onClick={() => setShouldDisplayDescription(true)}
          data-test="show-description"
        >
          {translate('text_642d5eb2783a2ad10d670324')}
        </Button>
      )}

      <form.AppField name="interval">
        {(field) => (
          <field.ButtonSelectorField
            disabled={isInSubscriptionForm || (isEdition && !canBeEdited)}
            label={translate('text_6661fc17337de3591e29e3d1')}
            description={translate('text_6661fc17337de3591e29e3d3')}
            options={intervalOptions}
          />
        )}
      </form.AppField>

      {canApplyChargesMonthly && (
        <>
          {hasAnyFixedCharge && (
            <form.AppField name="billFixedChargesMonthly">
              {(field) => (
                <field.SwitchField
                  label={translate('text_1760729707268reew4lqsqof')}
                  subLabel={translate('text_1760729707268ge00k7a7e84')}
                  disabled={isInSubscriptionForm || (isEdition && !canBeEdited)}
                />
              )}
            </form.AppField>
          )}

          {hasAnyUsageCharge && (
            <form.AppField name="billChargesMonthly">
              {(field) => (
                <field.SwitchField
                  label={translate('text_62a30bc79dae432fb055330b')}
                  subLabel={translate('text_64358e074a3b7500714f256c')}
                  disabled={isInSubscriptionForm || (isEdition && !canBeEdited)}
                />
              )}
            </form.AppField>
          )}
        </>
      )}

      <form.AppField name="amountCurrency">
        {(field) => (
          <field.ComboBoxField
            data={CURRENCY_DATA}
            disableClearable
            disabled={
              subscriptionFormType === FORM_TYPE_ENUM.edition || (isEdition && !canBeEdited)
            }
            label={translate('text_642d5eb2783a2ad10d67032e')}
          />
        )}
      </form.AppField>

      <form.Subscribe selector={(state) => state.values.taxes}>
        {(taxes) => (
          <TaxesSelectorSection
            title={translate('text_1760729707267seik64l67k8')}
            description={translate('text_1770124786732u8hv8voejbl')}
            taxes={taxes || []}
            comboboxSelector={SEARCH_TAX_INPUT_FOR_PLAN_CLASSNAME}
            onUpdate={(newTaxArray) => {
              form.setFieldValue('taxes', newTaxArray)
            }}
          />
        )}
      </form.Subscribe>
    </CenteredPage.PageSection>
  )
}

PlanSettingsSection.displayName = 'PlanSettingsSection'
