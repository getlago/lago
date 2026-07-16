import { gql } from '@apollo/client'
import InputAdornment from '@mui/material/InputAdornment'
import { useStore } from '@tanstack/react-form'
import { useCallback, useMemo } from 'react'

import { Alert } from '~/components/designSystem/Alert'
import { Selector } from '~/components/designSystem/Selector'
import { Typography } from '~/components/designSystem/Typography'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { ChargeModelSelector } from '~/components/plans/chargeAccordion/ChargeModelSelector'
import { ChargeWrapperSwitch } from '~/components/plans/chargeAccordion/ChargeWrapperSwitch'
import { ChargePayInAdvanceOption } from '~/components/plans/chargeAccordion/options/ChargePayInAdvanceOption'
import { seedChargeCode } from '~/components/plans/drawers/common/chargeCode'
import ChargeCodeField from '~/components/plans/drawers/common/ChargeCodeField'
import { buildCodeComboboxItem } from '~/components/plans/drawers/common/codeComboboxItem'
import { PlanBillingPeriodInfoSection } from '~/components/plans/drawers/common/PlanBillingPeriodInfoSection'
import { LocalFixedChargeInput } from '~/components/plans/types'
import { TaxesSelectorSection } from '~/components/taxes/TaxesSelectorSection'
import { usePlanFormContext } from '~/contexts/PlanFormContext'
import {
  SEARCH_ADD_ON_IN_FIXED_CHARGE_DRAWER_INPUT_CLASSNAME,
  SEARCH_TAX_INPUT_FOR_CHARGE_CLASSNAME,
} from '~/core/constants/form'
import getPropertyShape from '~/core/serializers/getPropertyShape'
import {
  FixedChargeChargeModelEnum,
  GraduatedChargeFragmentDoc,
  TaxForPlanAndChargesInPlanFormFragmentDoc,
  useGetAddOnsForFixedChargesSectionLazyQuery,
  VolumeRangesFragmentDoc,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withForm } from '~/hooks/forms/useAppform'
import { useChargeForm } from '~/hooks/plans/useChargeForm'

import { DEFAULT_VALUES, type FixedChargeDrawerFormValues } from './constants'

gql`
  fragment AddOnForFixedChargesSection on AddOn {
    id
    name
    code
  }

  query getAddOnsForFixedChargesSection($page: Int, $limit: Int, $searchTerm: String) {
    addOns(page: $page, limit: $limit, searchTerm: $searchTerm) {
      metadata {
        currentPage
        totalPages
      }
      collection {
        id
        ...AddOnForFixedChargesSection
      }
    }
  }

  ${TaxForPlanAndChargesInPlanFormFragmentDoc}
  ${GraduatedChargeFragmentDoc}
  ${VolumeRangesFragmentDoc}
`

interface FixedChargeDrawerContentExtraProps {
  isCreateMode: boolean
  isEdition: boolean
  isInSubscriptionForm: boolean
  disabled: boolean
  alertMessage?: string
  // TEMP (LAGO-1498): Code is shown only via the v2 details/edition UI.
  showCode?: boolean
  existingChargeCodes?: (string | null | undefined)[]
}

const fixedChargeDrawerContentDefaultProps: FixedChargeDrawerContentExtraProps = {
  isCreateMode: false,
  isEdition: false,
  isInSubscriptionForm: false,
  disabled: false,
  alertMessage: undefined,
  showCode: false,
  existingChargeCodes: undefined,
}

export const FixedChargeDrawerContent = withForm({
  defaultValues: DEFAULT_VALUES,
  props: fixedChargeDrawerContentDefaultProps,
  render: function FixedChargeDrawerContentRender({
    form,
    isCreateMode,
    isEdition,
    isInSubscriptionForm,
    disabled,
    alertMessage,
    showCode,
    existingChargeCodes,
  }) {
    const { translate } = useInternationalization()
    const { currency } = usePlanFormContext()

    const formValues = useStore(form.store, (state) => state.values)
    const isCreatePickerScreen = isCreateMode && !formValues.addOnId

    // Only disable fields for charges that already exist on the backend (have an id)
    // New charges added to a subscribed plan should remain fully editable
    const isExistingCharge = !!formValues.id
    const isExistingChargeDisabled = disabled && isExistingCharge

    const [getAddOnsForFixedChargesSection, { loading: addOnsLoading, data: addOnsData }] =
      useGetAddOnsForFixedChargesSectionLazyQuery({
        variables: { limit: 1000 },
      })

    const addOnsComboboxData = useMemo(() => {
      if (!addOnsData?.addOns?.collection?.length) return []

      return addOnsData.addOns.collection.map(({ id, name, code }) =>
        buildCodeComboboxItem({ id, name, code }),
      )
    }, [addOnsData?.addOns?.collection])

    const {
      getFixedChargeModelComboboxData,
      getIsPayInAdvanceOptionDisabledForFixedCharge,
      getIsProRatedOptionDisabledForFixedCharge,
    } = useChargeForm()

    const chargeModelComboboxData = useMemo(
      () => getFixedChargeModelComboboxData(),
      [getFixedChargeModelComboboxData],
    )

    const isPayInAdvanceOptionDisabled = useMemo(
      () =>
        getIsPayInAdvanceOptionDisabledForFixedCharge({
          chargeModel: formValues.chargeModel,
          isProrated: formValues.prorated,
        }),
      [getIsPayInAdvanceOptionDisabledForFixedCharge, formValues.chargeModel, formValues.prorated],
    )

    const isProratedOptionDisabled = useMemo(
      () =>
        getIsProRatedOptionDisabledForFixedCharge({
          chargeModel: formValues.chargeModel,
          isPayInAdvance: formValues.payInAdvance,
        }),
      [getIsProRatedOptionDisabledForFixedCharge, formValues.chargeModel, formValues.payInAdvance],
    )

    const handleChargeModelUpdate = useCallback(
      (name: string, value: unknown) => {
        if (name === 'chargeModel') {
          if (value === form.getFieldValue('chargeModel')) return

          form.reset(
            {
              ...form.state.values,
              chargeModel: value as FixedChargeChargeModelEnum,
              payInAdvance: false,
              prorated: false,
              properties: getPropertyShape({}),
              taxes: [],
            },
            { keepDefaultValues: true },
          )
          return
        }

        form.setFieldValue(
          name as keyof FixedChargeDrawerFormValues,
          value as FixedChargeDrawerFormValues[keyof FixedChargeDrawerFormValues],
        )
      },
      [form],
    )

    return (
      <CenteredPage.SectionWrapper>
        <CenteredPage.PageTitle
          title={translate('text_1772133285141kidk35mbh3o')}
          description={translate('text_1760729707268c05r06ip8vg')}
        />

        {isCreatePickerScreen ? (
          <CenteredPage.PageSection>
            <CenteredPage.PageSectionTitle
              title={translate('text_1772133285141caubzimuyr0')}
              description={translate('text_17727389218359nvq0qjg447')}
            />

            <form.AppField
              name="addOnId"
              listeners={{
                onChange: ({ value }) => {
                  const selectedAddOn = addOnsData?.addOns?.collection.find((a) => a.id === value)

                  if (selectedAddOn) {
                    form.setFieldValue('addOn', {
                      id: selectedAddOn.id,
                      name: selectedAddOn.name,
                      code: selectedAddOn.code,
                    })

                    seedChargeCode({
                      enabled: !!showCode && isCreateMode,
                      sourceCode: selectedAddOn.code,
                      existingChargeCodes,
                      setCode: (nextCode) => form.setFieldValue('code', nextCode),
                    })
                  }
                },
              }}
            >
              {(field) => (
                <field.ComboBoxField
                  className={SEARCH_ADD_ON_IN_FIXED_CHARGE_DRAWER_INPUT_CLASSNAME}
                  data={addOnsComboboxData}
                  searchQuery={getAddOnsForFixedChargesSection}
                  loading={addOnsLoading}
                  placeholder={translate('text_6453819268763979024ad0ad')}
                  emptyText={translate('text_655633c844bc8a00577061b0')}
                />
              )}
            </form.AppField>
          </CenteredPage.PageSection>
        ) : (
          <CenteredPage.SubsectionWrapper>
            {/* Selected add-on (read-only) */}
            <CenteredPage.PageSection>
              <CenteredPage.PageSectionTitle title={translate('text_1772133285141caubzimuyr0')} />

              <Selector
                icon="puzzle"
                title={formValues.addOn.name}
                subtitle={formValues.addOn.code}
              />

              {showCode && (
                <ChargeCodeField
                  form={form}
                  fields={{ code: 'code' }}
                  disabled={isInSubscriptionForm || isExistingChargeDisabled}
                />
              )}
            </CenteredPage.PageSection>

            {/* Pricing settings */}
            <CenteredPage.PageSection>
              <CenteredPage.PageSectionTitle title={translate('text_1772133285141xbpuxbd4vrk')} />

              <ChargeModelSelector
                alreadyUsedChargeAlertMessage={alertMessage}
                isInSubscriptionForm={isInSubscriptionForm}
                disabled={isExistingChargeDisabled}
                localCharge={formValues as unknown as LocalFixedChargeInput}
                chargeModelComboboxData={chargeModelComboboxData}
                handleUpdate={handleChargeModelUpdate}
              />

              <ChargeWrapperSwitch
                chargeType="fixed"
                chargePricingUnitShortName={undefined}
                currency={currency}
                form={form}
                isEdition={isEdition}
                localCharge={formValues as unknown as LocalFixedChargeInput}
                propertyCursor="properties"
              />

              <Alert type="info">
                <Typography variant="body" color="grey700">
                  {translate('text_1781789973520dpkwtttnk2m')}
                </Typography>
              </Alert>

              <form.AppField name="units">
                {(field) => (
                  <field.TextInputField
                    label={translate('text_65771fa3f4ab9a00720726ce')}
                    placeholder={translate('text_643e592657fc1ba5ce110c80')}
                    beforeChangeFormatter={['positiveNumber', 'sextDecimal']}
                    InputProps={{
                      endAdornment: (
                        <InputAdornment position="end">
                          {translate('text_6282085b4f283b0102655884')}
                        </InputAdornment>
                      ),
                    }}
                  />
                )}
              </form.AppField>

              {isEdition && (
                <form.AppField name="applyUnitsImmediately">
                  {(field) => (
                    <field.SwitchField
                      label={translate('text_1760721761361octnb0dfqm5')}
                      subLabel={translate('text_1760721761361lqhc17vjr2b')}
                    />
                  )}
                </form.AppField>
              )}
            </CenteredPage.PageSection>

            {/* Invoicing settings */}
            <CenteredPage.PageSection>
              <CenteredPage.PageSectionTitle title={translate('text_17423672025282dl7iozy1ru')} />

              <form.AppField name="invoiceDisplayName">
                {(field) => (
                  <field.TextInputField
                    label={translate('text_65a6b4e2cb38d9b70ec53d39')}
                    description={translate('text_1771963033467yduu33x3qw9')}
                    placeholder={translate('text_65a6b4e2cb38d9b70ec53d41')}
                  />
                )}
              </form.AppField>

              <PlanBillingPeriodInfoSection />

              <ChargePayInAdvanceOption
                form={form}
                fields={{ payInAdvance: 'payInAdvance' }}
                disabled={isInSubscriptionForm || isExistingChargeDisabled}
                isPayInAdvanceOptionDisabled={isPayInAdvanceOptionDisabled}
              />

              <div className="flex flex-col gap-4">
                <div className="flex flex-col gap-1">
                  <Typography variant="captionHl" color="grey700">
                    {translate('text_177488074309762bkd4znl3p')}
                  </Typography>
                  <Typography variant="caption" color="grey600">
                    {translate('text_1774880743098ioxd3oxanxo')}
                  </Typography>
                </div>

                <form.AppField name="prorated">
                  {(field) => (
                    <field.SwitchField
                      label={translate('text_177488074309762bkd4znl3p')}
                      disabled={
                        isInSubscriptionForm || isExistingChargeDisabled || isProratedOptionDisabled
                      }
                    />
                  )}
                </form.AppField>
              </div>

              <TaxesSelectorSection
                title={translate('text_1760729707267seik64l67k8')}
                description={translate('text_17607297072672w5hid8gl1i')}
                taxes={formValues.taxes}
                comboboxSelector={SEARCH_TAX_INPUT_FOR_CHARGE_CLASSNAME}
                onUpdate={(newTaxArray) => {
                  form.setFieldValue('taxes', newTaxArray)
                }}
              />
            </CenteredPage.PageSection>
          </CenteredPage.SubsectionWrapper>
        )}
      </CenteredPage.SectionWrapper>
    )
  },
})
