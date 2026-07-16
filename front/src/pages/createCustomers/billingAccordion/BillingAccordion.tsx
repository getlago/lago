import { useStore } from '@tanstack/react-form'
import { useEffect } from 'react'

import { Accordion } from '~/components/designSystem/Accordion'
import { Typography } from '~/components/designSystem/Typography'
import { AddCustomerDrawerFragment, CurrencyEnum, FeatureFlagEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withForm } from '~/hooks/forms/useAppform'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'

import BillingFields from './BillingFields'

type BillingAccordionProps = {
  customer?: AddCustomerDrawerFragment | null
}

const defaultProps: BillingAccordionProps = {
  customer: null,
}

const BillingAccordion = withForm({
  defaultValues: emptyCreateCustomerDefaultValues,
  props: defaultProps,
  render: function Render({ form, customer }) {
    const { translate } = useInternationalization()
    const { hasFeatureFlag } = useOrganizationInfos()

    const isCustomerLocked = !!customer && !customer?.canEditAttributes
    const hasMultiCurrency = hasFeatureFlag(FeatureFlagEnum.MultiCurrency)
    const isCurrencyDisabled = isCustomerLocked && !hasMultiCurrency

    // When the multi_currency flag is on, the currency never locks → no warning.
    // When the flag is off, mirror pre-epic behaviour: show the locked message
    // if the field is disabled, otherwise show the forward-looking warning.
    const getCurrencyInfoText = () => {
      if (hasMultiCurrency) return undefined
      if (isCurrencyDisabled) return translate('text_632c6e59b73f9a54d4c7223d')
      return translate('text_632c6e59b73f9a54d4c7223f')
    }

    const billingAddress = useStore(form.store, (state) => state.values.billingAddress)
    const isShippingEqualBillingAddress = useStore(
      form.store,
      (state) => state.values.isShippingEqualBillingAddress,
    )

    useEffect(() => {
      if (isShippingEqualBillingAddress) {
        form.setFieldValue('shippingAddress', billingAddress ? { ...billingAddress } : undefined)
      }
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [billingAddress, isShippingEqualBillingAddress])

    const currencyDataForCombobox = Object.values(CurrencyEnum).map((currencyType) => ({
      value: currencyType,
    }))

    return (
      <Accordion
        variant="borderless"
        summary={
          <div className="flex flex-col gap-2">
            <Typography variant="subhead1">{translate('text_632b49e2620ea4c6d96c9662')}</Typography>
            <Typography variant="caption">{translate('text_1735653854525b68ew2qbpdp')}</Typography>
          </div>
        }
      >
        <div className="not-last-child:mb-8">
          <div className="not-last-child:mb-6">
            <form.AppField name="currency">
              {(field) => (
                <field.ComboBoxField
                  disabled={isCurrencyDisabled}
                  label={translate('text_632c6e59b73f9a54d4c72247')}
                  placeholder={translate('text_632c6e59b73f9a54d4c7224b')}
                  infoText={getCurrencyInfoText()}
                  data={currencyDataForCombobox}
                  disableClearable
                />
              )}
            </form.AppField>
            <form.AppField name="legalName">
              {(field) => (
                <field.TextInputField
                  label={translate('text_626c0c09812bbc00e4c59e01')}
                  placeholder={translate('text_626c0c09812bbc00e4c59e03')}
                />
              )}
            </form.AppField>
            <form.AppField name="legalNumber">
              {(field) => (
                <field.TextInputField
                  label={translate('text_626c0c09812bbc00e4c59e05')}
                  placeholder={translate('text_626c0c09812bbc00e4c59e07')}
                />
              )}
            </form.AppField>
            <form.AppField name="taxIdentificationNumber">
              {(field) => (
                <field.TextInputField
                  label={translate('text_648053ee819b60364c675d05')}
                  placeholder={translate('text_648053ee819b60364c675d0b')}
                />
              )}
            </form.AppField>
            <form.AppField name="email">
              {(field) => (
                <field.TextInputField
                  beforeChangeFormatter={['lowercase']}
                  label={translate('text_626c0c09812bbc00e4c59e09')}
                  placeholder={translate('text_626c0c09812bbc00e4c59e0b')}
                  helperText={translate('text_641394c4c936000079c5639a')}
                />
              )}
            </form.AppField>
            <form.AppField name="url">
              {(field) => (
                <field.TextInputField
                  label={translate('text_641b15b0df87eb00848944ea')}
                  placeholder={translate('text_641b15e7ac746900b68377f9')}
                />
              )}
            </form.AppField>
            <form.AppField name="phone">
              {(field) => (
                <field.TextInputField
                  label={translate('text_626c0c09812bbc00e4c59e0d')}
                  placeholder={translate('text_626c0c09812bbc00e4c59e0f')}
                />
              )}
            </form.AppField>
          </div>
          <div className="not-last-child:mb-4">
            <Typography variant="bodyHl" color="textSecondary">
              {translate('text_626c0c301a16a600ea06148d')}
            </Typography>

            <BillingFields form={form} fields="billingAddress" />
          </div>
          <div className="not-last-child:mb-4">
            <Typography variant="bodyHl" color="textSecondary">
              {translate('text_667d708c1359b49f5a5a8230')}
            </Typography>
            <form.AppField name="isShippingEqualBillingAddress">
              {(field) => (
                <field.CheckboxField label={translate('text_667d708c1359b49f5a5a8234')} />
              )}
            </form.AppField>

            <BillingFields
              form={form}
              fields="shippingAddress"
              isDisabled={isShippingEqualBillingAddress}
            />
          </div>
        </div>
      </Accordion>
    )
  },
})

export default BillingAccordion
