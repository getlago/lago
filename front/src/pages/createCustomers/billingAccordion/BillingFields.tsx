import { countryDataForCombobox } from '~/core/formats/countryDataForCombobox'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withFieldGroup } from '~/hooks/forms/useAppform'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'

type BillingFieldsProps = {
  isDisabled?: boolean
}

const defaultProps: BillingFieldsProps = {
  isDisabled: false,
}

const BillingFields = withFieldGroup({
  // Used for typing validation. We only want the address part of the form
  defaultValues: { ...emptyCreateCustomerDefaultValues.shippingAddress },
  props: defaultProps,
  render: function Render({ group, isDisabled }) {
    const { translate } = useInternationalization()

    return (
      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        <group.AppField name="addressLine1">
          {(field) => (
            <field.TextInputField
              className="col-span-2"
              disabled={isDisabled}
              label={translate('text_626c0c09812bbc00e4c59e1d')}
              placeholder={translate('text_1735653854525cemtriccmuh')}
            />
          )}
        </group.AppField>
        <group.AppField name="addressLine2">
          {(field) => (
            <field.TextInputField
              className="col-span-2"
              disabled={isDisabled}
              label={translate('text_626c0c09812bbc00e4c59e1f')}
              placeholder={translate('text_1735653854525dq6plq7exd3')}
            />
          )}
        </group.AppField>
        <group.AppField name="zipcode">
          {(field) => (
            <field.TextInputField
              disabled={isDisabled}
              label={translate('text_626c0c09812bbc00e4c59e21')}
              placeholder={translate('text_1735654189136h4rgi3zdwaa')}
            />
          )}
        </group.AppField>
        <group.AppField name="city">
          {(field) => (
            <field.TextInputField
              disabled={isDisabled}
              label={translate('text_626c0c09812bbc00e4c59e23')}
              placeholder={translate('text_1735654189136vn4mbzp4jhs')}
            />
          )}
        </group.AppField>
        <group.AppField name="state">
          {(field) => (
            <field.TextInputField
              className="col-span-2"
              disabled={isDisabled}
              label={translate('text_626c0c09812bbc00e4c59e25')}
              placeholder={translate('text_173565418913690jb89ypb63')}
            />
          )}
        </group.AppField>
        <group.AppField name="country">
          {(field) => (
            <field.ComboBoxField
              containerClassName="col-span-2"
              disabled={isDisabled}
              label={translate('text_626c0c09812bbc00e4c59e27')}
              data={countryDataForCombobox}
              placeholder={translate('text_1735654189136s548dkluunb')}
              PopperProps={{ displayInDialog: true }}
            />
          )}
        </group.AppField>
      </div>
    )
  },
})

export default BillingFields
