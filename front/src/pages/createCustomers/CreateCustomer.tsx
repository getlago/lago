import { revalidateLogic } from '@tanstack/react-form'
import { Icon } from 'lago-design-system'
import { useRef } from 'react'

import { SUBMIT_CUSTOMER_DATA_TEST } from '~/components/customers/utils/dataTestConstants'
import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { WarningDialog, WarningDialogRef } from '~/components/designSystem/WarningDialog'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { extractThirdPartyErrorMessage, hasDefinedGQLError } from '~/core/apolloClient'
import { scrollToFirstInputError } from '~/core/form/scrollToFirstInputError'
import { PremiumIntegrationTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'
import { useBillingEntitiesOptions } from '~/hooks/useBillingEntitiesOptions'
import { useCreateEditCustomer } from '~/hooks/useCreateEditCustomer'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { FormLoadingSkeleton } from '~/styles/mainObjectsForm'

import BillingAccordion from './billingAccordion/BillingAccordion'
import { useAccountingProviders } from './common/useAccountingProviders'
import { useCrmProviders } from './common/useCrmProviders'
import { usePaymentProviders } from './common/usePaymentProviders'
import { useTaxProviders } from './common/useTaxProviders'
import CustomerInformation from './customerInformation/CustomerInformation'
import ExternalAppsAccordion from './externalAppsAccordion/ExternalAppsAccordion'
import { validationSchema } from './formInitialization/validationSchema'
import { mapFromApiToForm } from './mappers/mapFromApiToForm'
import { mapFromFormToApi } from './mappers/mapFromFormToApi'
import MetadataAccordion from './metadataAccordion/MetadataAccordion'

const STRIPE_CUSTOMER_ERROR_MESSAGE_DETAILS = 'Stripe: resource_missing'

const CreateCustomer = () => {
  const { translate } = useInternationalization()
  const warningDialogRef = useRef<WarningDialogRef>(null)
  const { open: openPremiumWarningDialog } = usePremiumWarningDialog()
  const { organization: { premiumIntegrations } = {} } = useOrganizationInfos()
  const { getPaymentProvider } = usePaymentProviders()
  const { taxProviders } = useTaxProviders()
  const { crmProviders } = useCrmProviders()
  const { accountingProviders } = useAccountingProviders()

  const hasAccessToRevenueShare = !!premiumIntegrations?.includes(
    PremiumIntegrationTypeEnum.RevenueShare,
  )

  const { isEdition, onSave, customer, loading, onClose } = useCreateEditCustomer()

  const {
    options: billingEntitiesList,
    isLoading: isLoadingBillingEntities,
    defaultEntityCode,
  } = useBillingEntitiesOptions()

  const isFormReady = !isLoadingBillingEntities && !loading

  const defaultBillingEntity = billingEntitiesList.find(
    (option) => option.value === defaultEntityCode,
  )

  const canEditAccountType =
    hasAccessToRevenueShare && (isEdition ? customer?.canEditAttributes : true)

  const form = useAppForm({
    defaultValues: mapFromApiToForm(customer, defaultBillingEntity),
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: validationSchema,
    },
    onSubmit: async ({ value, formApi }) => {
      const formattedValues = mapFromFormToApi(value, {
        paymentProvider: getPaymentProvider(value.paymentProviderCode),
        taxProviders,
        crmProviders,
        accountingProviders,
      })

      const answer = await onSave(formattedValues)

      const { errors } = answer

      if (hasDefinedGQLError('ValueAlreadyExist', errors)) {
        formApi.setErrorMap({
          onDynamic: {
            fields: {
              externalId: {
                message: 'text_626162c62f790600f850b728',
                path: ['externalId'],
              },
            },
          },
        })
        return
      }

      const thirdPartyErrorMessage = extractThirdPartyErrorMessage(errors)

      if (thirdPartyErrorMessage?.startsWith(STRIPE_CUSTOMER_ERROR_MESSAGE_DETAILS)) {
        formApi.setErrorMap({
          onDynamic: {
            fields: {
              'paymentProviderCustomer.providerCustomerId': {
                message: 'text_1772636865361lt8w6gchmv1',
                path: ['paymentProviderCustomer', 'providerCustomerId'],
              },
            },
          },
        })
        return
      }

      !isEdition && formApi.reset()
    },
    onSubmitInvalid({ formApi }) {
      scrollToFirstInputError('create-customer', formApi.state.errorMap.onDynamic || {})
    },
  })

  const handleAbort = () => {
    const isDirty = form.store.state.isDirty

    isDirty ? warningDialogRef.current?.openDialog() : onClose()
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    form.handleSubmit()
  }

  const getSubmitButtonText = () => {
    return isEdition
      ? translate('text_17295436903260tlyb1gp1i7')
      : translate('text_632b49e2620ea4c6d96c9666')
  }

  return (
    <CenteredPage.Wrapper>
      <form
        id="create-customer"
        className="flex size-full min-h-full flex-col overflow-auto"
        onSubmit={handleSubmit}
      >
        <CenteredPage.Header>
          <Typography variant="bodyHl" color="textSecondary" noWrap>
            {isEdition
              ? translate('text_1735651472114fzhjvrrcumw')
              : translate('text_1734452833961s338w0x3b4s')}
          </Typography>
          <Button variant="quaternary" icon="close" onClick={handleAbort} />
        </CenteredPage.Header>

        {!isFormReady && (
          <CenteredPage.Container>
            <FormLoadingSkeleton id="create-customer" />
          </CenteredPage.Container>
        )}

        {isFormReady && (
          <CenteredPage.Container>
            <div className="not-last-child:mb-1">
              <Typography variant="headline" color="textSecondary">
                {isEdition
                  ? translate('text_1735651472114fzhjvrrcumw')
                  : translate('text_1734452833961s338w0x3b4s')}
              </Typography>
              <Typography variant="body">{translate('text_1734452833961ix7z38723pg')}</Typography>
            </div>

            <div className="mb-8 flex flex-col gap-12 not-last-child:pb-12 not-last-child:shadow-b">
              {hasAccessToRevenueShare ? (
                <div className="flex items-center justify-between">
                  <form.AppField name="isPartner">
                    {(field) => (
                      <field.SwitchField
                        label={translate('text_173832066416253fgbilrnae')}
                        subLabel={translate('text_173832066416219scp0nqeo8')}
                        labelPosition="right"
                        disabled={!canEditAccountType}
                      />
                    )}
                  </form.AppField>
                </div>
              ) : (
                <button
                  type="button"
                  className="flex items-center justify-between"
                  onClick={() => {
                    openPremiumWarningDialog()
                  }}
                >
                  <form.AppField name="isPartner">
                    {(field) => (
                      <field.SwitchField
                        label={translate('text_173832066416253fgbilrnae')}
                        subLabel={translate('text_173832066416219scp0nqeo8')}
                        labelPosition="right"
                        disabled={!canEditAccountType}
                      />
                    )}
                  </form.AppField>
                  <Icon name="sparkles" />
                </button>
              )}

              <CustomerInformation
                form={form}
                isEdition={isEdition}
                isLoadingBillingEntities={isLoadingBillingEntities}
                customer={customer}
                billingEntitiesList={billingEntitiesList}
              />
              <BillingAccordion form={form} customer={customer} />
              <MetadataAccordion form={form} />
              <ExternalAppsAccordion form={form} isEdition={isEdition} customer={customer} />
            </div>
          </CenteredPage.Container>
        )}

        <CenteredPage.StickyFooter>
          <Button variant="quaternary" onClick={handleAbort}>
            {translate('text_62e79671d23ae6ff149de968')}
          </Button>
          <form.AppForm>
            <form.SubmitButton dataTest={SUBMIT_CUSTOMER_DATA_TEST}>
              {getSubmitButtonText()}
            </form.SubmitButton>
          </form.AppForm>
        </CenteredPage.StickyFooter>
      </form>

      <WarningDialog
        ref={warningDialogRef}
        title={translate('text_665deda4babaf700d603ea13')}
        description={translate('text_665dedd557dc3c00c62eb83d')}
        continueText={translate('text_645388d5bdbd7b00abffa033')}
        onContinue={onClose}
      />
    </CenteredPage.Wrapper>
  )
}

export default CreateCustomer
