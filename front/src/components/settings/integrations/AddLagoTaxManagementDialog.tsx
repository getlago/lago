import { useFormik } from 'formik'
import { tw } from 'lago-design-system'
import { forwardRef, useRef } from 'react'
import { generatePath } from 'react-router-dom'
import { array, object, string } from 'yup'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { Typography } from '~/components/designSystem/Typography'
import { ComboBoxField } from '~/components/form'
import { addToast } from '~/core/apolloClient'
import { LAGO_TAX_DOCUMENTATION_URL } from '~/core/constants/externalUrls'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { countryDataForCombobox } from '~/core/formats/countryDataForCombobox'
import { TAX_MANAGEMENT_INTEGRATION_ROUTE, useNavigate } from '~/core/router'
import {
  CountryCode,
  LagoApiError,
  useGetBillingEntitiesQuery,
  useUpdateBillingEntityMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useIntegrations } from '~/hooks/useIntegrations'

import { hasNonEuEligibilityError } from './utils'

type BillingEntityFormItem = {
  id?: string
  country?: CountryCode | null
  initialCountry?: CountryCode | null
}

export const ADD_LAGO_TAX_MANAGEMENT_SUBMIT_BUTTON_TEST_ID = 'add-lago-tax-management-submit-button'

export type AddLagoTaxManagementDialogRef = DialogRef

type AddLagoTaxManagementDialogProps = {
  isUpdate?: boolean
}

export const AddLagoTaxManagementDialog = forwardRef<
  AddLagoTaxManagementDialogRef,
  AddLagoTaxManagementDialogProps
>(({ isUpdate }, ref) => {
  const { translate } = useInternationalization()
  const { hasTaxProvider } = useIntegrations()
  const navigate = useNavigate()

  const { data: billingEntitiesData, loading: billingEntitiesLoading } =
    useGetBillingEntitiesQuery()

  const billingEntitiesList = billingEntitiesData?.billingEntities?.collection?.map(
    (billingEntity) => ({
      label: billingEntity.name || billingEntity.code,
      value: billingEntity.id,
    }),
  )

  const maxBillingEntities = billingEntitiesList?.length || 0

  const [update] = useUpdateBillingEntityMutation({
    context: {
      silentErrorCodes: [LagoApiError.UnprocessableEntity],
    },
  })

  const submitSucceededRef = useRef(false)

  const formikProps = useFormik<{
    billingEntities: Array<BillingEntityFormItem>
  }>({
    initialValues: {
      billingEntities:
        billingEntitiesData?.billingEntities?.collection
          ?.filter((billingEntity) => billingEntity?.euTaxManagement === true)
          .map((billingEntity) => ({
            id: billingEntity.id,
            country: billingEntity.country,
            initialCountry: billingEntity?.country,
          })) || [],
    },
    validationSchema: object().shape({
      billingEntities: array()
        .of(
          object({
            id: string().required(),
            country: string().required(),
          }),
        )
        .min(isUpdate ? 0 : 1, ''),
    }),
    onSubmit: async (values) => {
      submitSucceededRef.current = false
      const entities = billingEntitiesData?.billingEntities?.collection || []

      const results = await Promise.all(
        entities.map((billingEntity) => {
          const updated = values.billingEntities.find((b) => b.id === billingEntity.id)

          return update({
            variables: {
              input: {
                id: billingEntity.id as string,
                country: updated?.country || billingEntity.country,
                euTaxManagement: !!updated,
              },
            },
          })
        }),
      )

      const hasErrors = results.some((res) => !!res.errors)

      if (hasErrors) {
        if (hasNonEuEligibilityError(results)) {
          addToast({
            severity: 'danger',
            message: translate('text_1740672955723utwsgy8vzy2'),
          })
        }

        return
      }

      submitSucceededRef.current = true

      navigate(
        generatePath(TAX_MANAGEMENT_INTEGRATION_ROUTE, {
          integrationGroup: IntegrationsTabsOptionsEnum.Community,
        }),
      )

      addToast({
        message: translate('text_1746630247115t9xocnxcb1n'),
        severity: 'success',
      })
    },
    validateOnMount: true,
    enableReinitialize: true,
  })

  const canCreateBillingEntity = formikProps.values.billingEntities?.length < maxBillingEntities

  const availableBillingEntities = billingEntitiesList?.filter(
    (b) => !formikProps.values.billingEntities.find((bl) => bl.id === b.value),
  )

  const originalBillingEntity = (id: string) => {
    const entity = billingEntitiesData?.billingEntities?.collection?.find((b) => b.id === id)

    if (!entity) {
      return null
    }

    return {
      value: entity.id,
      label: entity?.name || entity?.code,
    }
  }

  const removeBillingEntity = (index: number) => {
    const billingEntities = [...(formikProps.values.billingEntities || [])]

    billingEntities.splice(index, 1)

    formikProps.setFieldValue('billingEntities', billingEntities)
  }

  const createEmptyBillingEntity = () => {
    if (canCreateBillingEntity) {
      formikProps.setFieldValue('billingEntities', formikProps.values.billingEntities.concat({}))
    }
  }

  const availableBillingEntitiesForEntity = (id?: string) => {
    if (!id) {
      return availableBillingEntities
    }

    const original = originalBillingEntity(id)

    if (original) {
      return (availableBillingEntities || []).concat(original)
    }

    return availableBillingEntities
  }

  const onBillingEntityIdChange = (id: string, index: number) => {
    const entity = billingEntitiesData?.billingEntities?.collection?.find((_b) => _b.id === id)

    if (!id) {
      return formikProps.setFieldValue(`billingEntities[${index}]`, {})
    }

    if (entity?.country) {
      return formikProps.setFieldValue(`billingEntities[${index}]`, {
        id: entity.id,
        country: entity.country,
        initialCountry: entity.country,
      })
    }

    return formikProps.setFieldValue(`billingEntities[${index}]`, {
      id: entity?.id,
    })
  }

  const onBillingEntityCountryChange = (country: string, index: number) => {
    return formikProps.setFieldValue(`billingEntities[${index}]`, {
      ...formikProps.values.billingEntities[index],
      country,
    })
  }

  return (
    <Dialog
      ref={ref}
      title={translate('text_657078c28394d6b1ae1b974d')}
      description={
        <Typography
          variant="body"
          color="grey600"
          html={translate('text_657078c28394d6b1ae1b9759', {
            href: LAGO_TAX_DOCUMENTATION_URL,
          })}
        />
      }
      onClose={() => {
        formikProps.resetForm()
        formikProps.validateForm()
      }}
      actions={({ closeDialog }) => (
        <>
          <Button variant="quaternary" onClick={closeDialog}>
            {translate('text_63eba8c65a6c8043feee2a14')}
          </Button>

          <Button
            data-test={ADD_LAGO_TAX_MANAGEMENT_SUBMIT_BUTTON_TEST_ID}
            variant="primary"
            disabled={!formikProps.isValid}
            onClick={async () => {
              await formikProps.submitForm()

              if (submitSucceededRef.current) {
                closeDialog()
              }
            }}
          >
            {translate(
              isUpdate ? 'text_1746700487143wqtrv2xw3c7' : 'text_657078c28394d6b1ae1b9789',
            )}
          </Button>
        </>
      )}
    >
      <div className="flex flex-col gap-3">
        {formikProps.values.billingEntities?.length > 0 && (
          <div className="grid grid-cols-7 gap-3">
            <div className="col-span-3">
              <Typography variant="bodyHl" color="grey700">
                {translate('text_1743077296189ms0shds6g53')}
              </Typography>
            </div>

            <div className="col-span-3">
              <Typography variant="bodyHl" color="grey700">
                {translate('text_62ab2d0396dd6b0361614da0')}
              </Typography>
            </div>
          </div>
        )}

        {formikProps.values.billingEntities.map((_b, index) => (
          <div
            className="grid grid-cols-7 gap-3"
            key={`add-lago-tax-management-billing-entity-${index}`}
          >
            <div className="col-span-3">
              <ComboBoxField
                name={`billingEntities[${index}].id`}
                placeholder={translate('text_174360002513391n72uwg6bb')}
                formikProps={formikProps}
                PopperProps={{ displayInDialog: true }}
                loading={billingEntitiesLoading}
                data={availableBillingEntitiesForEntity(_b.id)}
                sortValues={false}
                customOnChange={(val: string) => onBillingEntityIdChange(val, index)}
              />
            </div>

            <div className="col-span-3">
              <ComboBoxField
                data={countryDataForCombobox}
                name={`billingEntities[${index}].country`}
                placeholder={translate('text_657078c28394d6b1ae1b9771')}
                formikProps={formikProps}
                PopperProps={{ displayInDialog: true }}
                disabled={!!_b.initialCountry}
                disableClearable={!!_b.initialCountry}
                customOnChange={(val: string) => onBillingEntityCountryChange(val, index)}
              />
            </div>

            <div className="flex items-center justify-center">
              <Button
                className="col-span-1"
                variant="quaternary"
                size="medium"
                icon="trash"
                onClick={() => removeBillingEntity(index)}
                disabled={isUpdate && index === 0}
              />
            </div>
          </div>
        ))}
      </div>

      <Button
        fitContent
        variant="inline"
        size="medium"
        startIcon="plus"
        disabled={!canCreateBillingEntity}
        className={tw({
          'mt-6': formikProps.values.billingEntities?.length > 0,
          'mb-6': true,
        })}
        onClick={() => createEmptyBillingEntity()}
      >
        {translate('text_1746629562868pknl1wo22fa')}
      </Button>

      {hasTaxProvider && (
        <Alert type="info" className="mb-6">
          <Typography variant="body" color="grey700">
            {translate('text_66ba65e562cbc500f04c7dbb')}
          </Typography>
        </Alert>
      )}
    </Dialog>
  )
})

AddLagoTaxManagementDialog.displayName = 'AddLagoTaxManagementDialog'
