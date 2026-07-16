import { gql } from '@apollo/client'
import { revalidateLogic } from '@tanstack/react-form'
import { useState } from 'react'

import { useCustomerPortalData } from '~/components/customerPortal/common/hooks/useCustomerPortalData'
import useCustomerPortalNavigation from '~/components/customerPortal/common/hooks/useCustomerPortalNavigation'
import PageTitle from '~/components/customerPortal/common/PageTitle'
import SectionError from '~/components/customerPortal/common/SectionError'
import { LoaderCustomerInformationPage } from '~/components/customerPortal/common/SectionLoading'
import useCustomerPortalTranslate from '~/components/customerPortal/common/useCustomerPortalTranslate'
import { TRANSLATIONS_MAP_CUSTOMER_TYPE } from '~/components/customers/utils'
import { Alert } from '~/components/designSystem/Alert'
import { Typography } from '~/components/designSystem/Typography'
import { Checkbox } from '~/components/form'
import { countryDataForCombobox } from '~/core/formats/countryDataForCombobox'
import {
  CustomerTypeEnum,
  UpdateCustomerPortalCustomerInput,
  useUpdatePortalCustomerMutation,
} from '~/generated/graphql'
import { useAppForm } from '~/hooks/forms/useAppform'

import { editCustomerBillingValidationSchema, mapCustomerToFormValues } from './validationSchema'

type EditCustomerBillingFormProps = {
  customer?: UpdateCustomerPortalCustomerInput | null
  onSuccess?: () => void
}

gql`
  mutation updatePortalCustomer($input: UpdateCustomerPortalCustomerInput!) {
    updateCustomerPortalCustomer(input: $input) {
      id
    }
  }
`

const EditCustomerBillingForm = ({ customer, onSuccess }: EditCustomerBillingFormProps) => {
  const { translate } = useCustomerPortalTranslate()

  const initialValues = mapCustomerToFormValues(customer)
  const shipping = initialValues.shippingAddress

  const addressFieldsMatch =
    !!shipping &&
    shipping.addressLine1 === initialValues.addressLine1 &&
    shipping.addressLine2 === initialValues.addressLine2 &&
    shipping.city === initialValues.city &&
    shipping.country === initialValues.country &&
    shipping.state === initialValues.state &&
    shipping.zipcode === initialValues.zipcode

  const [isShippingEqualBillingAddress, setIsShippingEqualBillingAddress] =
    useState(addressFieldsMatch)

  const [
    updatePortalCustomer,
    { loading: updatePortalCustomerLoading, error: updatePortalCustomerError },
  ] = useUpdatePortalCustomerMutation({
    refetchQueries: ['getCustomerPortalData'],
    onCompleted(res) {
      if (res) {
        onSuccess?.()
      }
    },
  })

  const form = useAppForm({
    defaultValues: initialValues,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: editCustomerBillingValidationSchema,
    },
    onSubmit: async ({ value }) => {
      const { shippingAddress, ...rest } = value

      const normalizedShippingAddress = shippingAddress
        ? Object.fromEntries(
            Object.entries(shippingAddress).map(([key, v]) => [
              key,
              v === undefined || v === '' ? null : v,
            ]),
          )
        : shippingAddress

      updatePortalCustomer({
        variables: {
          input: {
            ...rest,
            shippingAddress: normalizedShippingAddress,
          },
        },
      })
    },
  })

  const syncShippingAddress = () => {
    const values = form.store.state.values

    form.setFieldValue('shippingAddress', {
      addressLine1: values.addressLine1,
      addressLine2: values.addressLine2,
      city: values.city,
      country: values.country,
      state: values.state,
      zipcode: values.zipcode,
    })
  }

  const billingAddressChangeListener = {
    onChange: () => {
      if (isShippingEqualBillingAddress) {
        syncShippingAddress()
      }
    },
  }

  if (!customer) {
    return null
  }

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault()
    form.handleSubmit()
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4">
      <Typography variant="subhead2" color="grey700">
        {translate('text_1728377307159eu0ihwiyrf0')}
      </Typography>

      <form.AppField name="customerType">
        {(field) => (
          <field.ComboBoxField
            label={translate('text_1726128938631ioz4orixel3')}
            placeholder={translate('text_17261289386318j0nhr1ms3t')}
            PopperProps={{ displayInDialog: true }}
            data={Object.values(CustomerTypeEnum).map((customerValue) => ({
              value: customerValue,
              label: translate(TRANSLATIONS_MAP_CUSTOMER_TYPE[customerValue]),
            }))}
          />
        )}
      </form.AppField>

      <form.AppField name="name">
        {(field) => (
          <field.TextInputField
            label={translate('text_634687079be251fdb43833cb')}
            placeholder={translate('text_1728654170904707saidat0f')}
          />
        )}
      </form.AppField>

      <div className="grid grid-cols-2 gap-4">
        <form.AppField name="firstname">
          {(field) => (
            <field.TextInputField
              label={translate('text_1726128938631ggtf2ggqs4b')}
              placeholder={translate('text_1726128938631ntcpbzv7x7s')}
            />
          )}
        </form.AppField>

        <form.AppField name="lastname">
          {(field) => (
            <field.TextInputField
              label={translate('text_1726128938631ymctg83bygm')}
              placeholder={translate('text_1726128938631xmpsba9ssuo')}
            />
          )}
        </form.AppField>
      </div>

      <form.AppField name="legalName">
        {(field) => (
          <field.TextInputField
            label={translate('text_626c0c09812bbc00e4c59e01')}
            placeholder={translate('text_626c0c09812bbc00e4c59e03')}
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
          />
        )}
      </form.AppField>

      <Typography variant="subhead2" color="grey700" className="mt-12">
        {translate('text_1728377307159y9afykbx2q9')}
      </Typography>

      <form.AppField name="addressLine1" listeners={billingAddressChangeListener}>
        {(field) => (
          <field.TextInputField
            label={translate('text_626c0c09812bbc00e4c59e1b')}
            placeholder={translate('text_626c0c09812bbc00e4c59e1d')}
          />
        )}
      </form.AppField>
      <form.AppField name="addressLine2" listeners={billingAddressChangeListener}>
        {(field) => (
          <field.TextInputField placeholder={translate('text_626c0c09812bbc00e4c59e1f')} />
        )}
      </form.AppField>

      <div className="grid grid-cols-2 gap-4">
        <form.AppField name="zipcode" listeners={billingAddressChangeListener}>
          {(field) => (
            <field.TextInputField placeholder={translate('text_626c0c09812bbc00e4c59e21')} />
          )}
        </form.AppField>
        <form.AppField name="city" listeners={billingAddressChangeListener}>
          {(field) => (
            <field.TextInputField placeholder={translate('text_626c0c09812bbc00e4c59e23')} />
          )}
        </form.AppField>
      </div>

      <form.AppField name="state" listeners={billingAddressChangeListener}>
        {(field) => (
          <field.TextInputField placeholder={translate('text_626c0c09812bbc00e4c59e25')} />
        )}
      </form.AppField>
      <form.AppField name="country" listeners={billingAddressChangeListener}>
        {(field) => (
          <field.ComboBoxField
            data={countryDataForCombobox}
            placeholder={translate('text_626c0c09812bbc00e4c59e27')}
            PopperProps={{ displayInDialog: true }}
          />
        )}
      </form.AppField>

      <Typography variant="subhead2" color="grey700" className="mt-8">
        {translate('text_667d708c1359b49f5a5a8230')}
      </Typography>

      <Checkbox
        label={translate('text_667d708c1359b49f5a5a8234')}
        value={isShippingEqualBillingAddress}
        onChange={() => {
          const next = !isShippingEqualBillingAddress

          setIsShippingEqualBillingAddress(next)
          if (next) {
            syncShippingAddress()
          }
        }}
      />
      <form.AppField name="shippingAddress.addressLine1">
        {(field) => (
          <field.TextInputField
            label={translate('text_626c0c09812bbc00e4c59e1b')}
            placeholder={translate('text_626c0c09812bbc00e4c59e1d')}
            disabled={isShippingEqualBillingAddress}
          />
        )}
      </form.AppField>
      <form.AppField name="shippingAddress.addressLine2">
        {(field) => (
          <field.TextInputField
            placeholder={translate('text_626c0c09812bbc00e4c59e1f')}
            disabled={isShippingEqualBillingAddress}
          />
        )}
      </form.AppField>

      <div className="grid grid-cols-2 gap-4">
        <form.AppField name="shippingAddress.zipcode">
          {(field) => (
            <field.TextInputField
              placeholder={translate('text_626c0c09812bbc00e4c59e21')}
              disabled={isShippingEqualBillingAddress}
            />
          )}
        </form.AppField>
        <form.AppField name="shippingAddress.city">
          {(field) => (
            <field.TextInputField
              placeholder={translate('text_626c0c09812bbc00e4c59e23')}
              disabled={isShippingEqualBillingAddress}
            />
          )}
        </form.AppField>
      </div>

      <form.AppField name="shippingAddress.state">
        {(field) => (
          <field.TextInputField
            placeholder={translate('text_626c0c09812bbc00e4c59e25')}
            disabled={isShippingEqualBillingAddress}
          />
        )}
      </form.AppField>
      <form.AppField
        name="shippingAddress.country"
        listeners={{
          onChange: ({ value }) => {
            // ComboBoxFieldForTanstack clears to undefined, but nested fields
            // need an explicit setFieldValue to propagate properly
            if (value === undefined) {
              form.setFieldValue('shippingAddress.country', null)
            }
          },
        }}
      >
        {(field) => (
          <field.ComboBoxField
            data={countryDataForCombobox}
            placeholder={translate('text_626c0c09812bbc00e4c59e27')}
            disabled={isShippingEqualBillingAddress}
            PopperProps={{ displayInDialog: true }}
          />
        )}
      </form.AppField>

      {updatePortalCustomerError && (
        <Alert className="mt-8" type="danger" data-test="error-alert">
          <Typography>{translate('text_1728377307160tb09yisgxk9')}</Typography>
        </Alert>
      )}

      <div className="flex justify-end">
        <div>
          <form.AppForm>
            <form.SubmitButton
              className="mt-8"
              size="medium"
              loading={updatePortalCustomerLoading}
              fullWidth
              data-test="submit"
            >
              {translate('text_17283773071596dmecu79kx4')}
            </form.SubmitButton>
          </form.AppForm>
        </div>
      </div>
    </form>
  )
}

const CustomerInformationPage = () => {
  const { goHome } = useCustomerPortalNavigation()
  const { translate } = useCustomerPortalTranslate()

  const {
    data: portalCustomerInfosData,
    loading: portalCustomerInfosLoading,
    error: portalCustomerInfosError,
    refetch: portalCustomerInfosRefetch,
  } = useCustomerPortalData()

  const customerPortalUser = portalCustomerInfosData?.customerPortalUser

  const isLoading = portalCustomerInfosLoading
  const isError = !isLoading && portalCustomerInfosError

  if (isError) {
    return (
      <div>
        <PageTitle title={translate('text_1728377307159nbrs3pgng03')} goHome={goHome} />

        <SectionError refresh={() => portalCustomerInfosRefetch} />
      </div>
    )
  }

  return (
    <div>
      <PageTitle title={translate('text_1728377307159nbrs3pgng03')} goHome={goHome} />

      {isLoading && <LoaderCustomerInformationPage />}

      {!isLoading && <EditCustomerBillingForm customer={customerPortalUser} onSuccess={goHome} />}
    </div>
  )
}

export default CustomerInformationPage
