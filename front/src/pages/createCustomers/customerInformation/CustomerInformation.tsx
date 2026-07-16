import { useStore } from '@tanstack/react-form'
import { useMemo } from 'react'

import { BillingEntityTaxAlerts } from '~/components/billingEntity/BillingEntityTaxAlerts'
import { TRANSLATIONS_MAP_CUSTOMER_TYPE } from '~/components/customers/utils'
import { Typography } from '~/components/designSystem/Typography'
import { getTimezoneConfig } from '~/core/timezone'
import {
  AddCustomerDrawerFragment,
  CustomerTypeEnum,
  FeatureFlagEnum,
  TimezoneEnum,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withForm } from '~/hooks/forms/useAppform'
import { BillingEntityOption } from '~/hooks/useBillingEntitiesOptions'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'

import HelperText from './HelperText'

type CustomerInformationProps = {
  isEdition?: boolean
  customer?: AddCustomerDrawerFragment | null
  billingEntitiesList: BillingEntityOption[]
  isLoadingBillingEntities: boolean
}

// Only used for typing or as default value
const defaultProps: CustomerInformationProps = {
  isEdition: false,
  customer: null,
  billingEntitiesList: [],
  isLoadingBillingEntities: false,
}

const CustomerInformation = withForm({
  // Only used for typing or as default value
  defaultValues: emptyCreateCustomerDefaultValues,
  // Used for typing and fallback values
  props: defaultProps,
  render: function Render({
    form,
    isEdition,
    customer,
    billingEntitiesList,
    isLoadingBillingEntities,
  }) {
    const { translate } = useInternationalization()
    const { isPremium } = useCurrentUser()
    const { hasFeatureFlag } = useOrganizationInfos()

    const canEditBillingEntity =
      !isEdition ||
      customer?.canEditAttributes ||
      hasFeatureFlag(FeatureFlagEnum.MultiEntityBilling)

    const hasMultiEntityBilling = hasFeatureFlag(FeatureFlagEnum.MultiEntityBilling)
    const selectedBillingEntityCode = useStore(
      form.store,
      (state) => state.values.billingEntityCode,
    )

    const timezoneComboboxData = useMemo(
      () =>
        Object.values(TimezoneEnum).map((timezoneValue) => ({
          value: timezoneValue,
          label: translate('text_638f743fa9a2a9545ee6409a', {
            zone: translate(timezoneValue),
            offset: getTimezoneConfig(timezoneValue).offset,
          }),
        })),
      [translate],
    )

    const customerTypeData = [
      {
        value: CustomerTypeEnum.Company,
        label: translate(TRANSLATIONS_MAP_CUSTOMER_TYPE[CustomerTypeEnum.Company]),
      },
      {
        value: CustomerTypeEnum.Individual,
        label: translate(TRANSLATIONS_MAP_CUSTOMER_TYPE[CustomerTypeEnum.Individual]),
      },
    ]

    return (
      <div className="flex flex-col gap-6">
        <div className="flex flex-col gap-2">
          <Typography variant="subhead1">{translate('text_6419c64eace749372fc72b07')}</Typography>
          <Typography variant="caption">{translate('text_1735652987833k0i3l9ill5g')}</Typography>
        </div>

        <form.AppField name="billingEntityCode">
          {(field) => (
            <field.ComboBoxField
              label={translate('text_1743611497157teaa1zu8l24')}
              placeholder={translate('text_174360002513391n72uwg6bb')}
              disabled={!canEditBillingEntity}
              PopperProps={{ displayInDialog: true }}
              loading={isLoadingBillingEntities}
              data={billingEntitiesList}
              disableClearable
              sortValues={false}
            />
          )}
        </form.AppField>

        {hasMultiEntityBilling && (
          <BillingEntityTaxAlerts
            currentBillingEntity={customer?.billingEntity}
            selectedBillingEntityCode={selectedBillingEntityCode}
            billingEntities={billingEntitiesList}
          />
        )}

        <form.AppField name="externalId">
          {(field) => (
            <field.TextInputField
              // eslint-disable-next-line jsx-a11y/no-autofocus
              autoFocus={!isEdition}
              label={translate('text_624efab67eb2570101d117ce')}
              placeholder={translate('text_624efab67eb2570101d117d6')}
              disabled={isEdition && !customer?.canEditAttributes}
            />
          )}
        </form.AppField>

        <form.AppField name="customerType">
          {(field) => (
            <field.ComboBoxField
              label={translate('text_1726128938631ioz4orixel3')}
              placeholder={translate('text_17261289386318j0nhr1ms3t')}
              PopperProps={{ displayInDialog: true }}
              data={customerTypeData}
            />
          )}
        </form.AppField>

        <form.AppField name="name">
          {(field) => (
            <field.TextInputField
              label={translate('text_624efab67eb2570101d117be')}
              placeholder={translate('text_624efab67eb2570101d117c6')}
            />
          )}
        </form.AppField>

        <div className="flex gap-6">
          <form.AppField name="firstname">
            {(field) => (
              <field.TextInputField
                className="w-full"
                label={translate('text_1726128938631ggtf2ggqs4b')}
                placeholder={translate('text_1726128938631ntcpbzv7x7s')}
              />
            )}
          </form.AppField>

          <form.AppField name="lastname">
            {(field) => (
              <field.TextInputField
                className="w-full"
                label={translate('text_1726128938631ymctg83bygm')}
                placeholder={translate('text_1726128938631xmpsba9ssuo')}
              />
            )}
          </form.AppField>
        </div>

        <form.AppField name="timezone">
          {(field) => (
            <field.ComboBoxField
              label={translate('text_6390a4ffef9227ba45daca90')}
              placeholder={translate('text_6390a4ffef9227ba45daca92')}
              disabled={!isPremium}
              helperText={<HelperText billingEntityCode={customer?.billingEntity?.code || ''} />}
              PopperProps={{ displayInDialog: true }}
              data={timezoneComboboxData}
            />
          )}
        </form.AppField>

        <form.AppField name="externalSalesforceId">
          {(field) => (
            <field.TextInputField
              label={translate('text_651fd3f644384c00999fbd81')}
              placeholder={translate('text_651fd408a57493006d00504e')}
              helperText={translate('text_651fd41846f44c0064408b07')}
            />
          )}
        </form.AppField>
      </div>
    )
  },
})

export default CustomerInformation
