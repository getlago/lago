import { revalidateLogic, useStore } from '@tanstack/react-form'
import { useCallback, useMemo, useRef } from 'react'
import { z } from 'zod'

import { Button } from '~/components/designSystem/Button'
import { Card } from '~/components/designSystem/Card'
import { Selector, SelectorActions } from '~/components/designSystem/Selector'
import { Typography } from '~/components/designSystem/Typography'
import { VirtualFilterList } from '~/components/designSystem/VirtualList/VirtualFilterList'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { DRAWER_TRANSITION_DURATION } from '~/components/drawers/const'
import { useDrawer } from '~/components/drawers/useDrawer'
import { JsonEditor } from '~/components/form'
import { ComboboxDataGrouped } from '~/components/form/ComboBox/types'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { buildChargeFilterAddFilterButtonId } from '~/components/plans/chargeAccordion/ChargeFilter'
import { ChargeModelSelector } from '~/components/plans/chargeAccordion/ChargeModelSelector'
import { ChargeWrapperSwitch } from '~/components/plans/chargeAccordion/ChargeWrapperSwitch'
import { CustomPricingUnitSelector } from '~/components/plans/chargeAccordion/CustomPricingUnitSelector'
import { ChargeInvoicingStrategyOption } from '~/components/plans/chargeAccordion/options/ChargeInvoicingStrategyOption'
import { ChargePayInAdvanceOption } from '~/components/plans/chargeAccordion/options/ChargePayInAdvanceOption'
import { SpendingMinimumOptionSection } from '~/components/plans/chargeAccordion/SpendingMinimumOptionSection'
import { seedChargeCode } from '~/components/plans/drawers/common/chargeCode'
import ChargeCodeField from '~/components/plans/drawers/common/ChargeCodeField'
import { buildCodeComboboxItem } from '~/components/plans/drawers/common/codeComboboxItem'
import { PlanBillingPeriodInfoSection } from '~/components/plans/drawers/common/PlanBillingPeriodInfoSection'
import {
  LocalChargeFilterInput,
  LocalPricingUnitInput,
  LocalPricingUnitType,
  LocalUsageChargeInput,
} from '~/components/plans/types'
import { mapChargeIntervalCopy } from '~/components/plans/utils'
import { TaxesSelectorSection } from '~/components/taxes/TaxesSelectorSection'
import { ChargeFilterDrawerProvider } from '~/contexts/ChargeFilterDrawerContext'
import {
  ALL_FILTER_VALUES,
  chargeModelLookupTranslation,
  FORM_TYPE_ENUM,
  SEARCH_BILLABLE_METRIC_IN_USAGE_CHARGE_DRAWER_INPUT_CLASSNAME,
  SEARCH_TAX_INPUT_FOR_CHARGE_CLASSNAME,
} from '~/core/constants/form'
import getPropertyShape from '~/core/serializers/getPropertyShape'
import {
  AggregationTypeEnum,
  ChargeModelEnum,
  CurrencyEnum,
  PlanInterval,
  useGetBillableMetricsLazyQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm, withForm } from '~/hooks/forms/useAppform'
import { useChargeForm } from '~/hooks/plans/useChargeForm'
import { useCustomPricingUnits } from '~/hooks/plans/useCustomPricingUnits'
import { useCurrentUser } from '~/hooks/useCurrentUser'

import {
  ChargeFilterDrawerContent,
  chargeFilterDrawerSchema,
  ChargeFilterFormValues,
} from './ChargeFilterDrawerContent'
import { DEFAULT_VALUES, UsageChargeDrawerFormValues } from './constants'

interface UsageChargeDrawerContentExtraProps {
  isCreateMode: boolean
  isEdition?: boolean
  disabled?: boolean
  isInSubscriptionForm?: boolean
  // TEMP (LAGO-1498): Code is shown only via the v2 details/edition UI.
  showCode?: boolean
  existingChargeCodes?: (string | null | undefined)[]
  subscriptionFormType?: keyof typeof FORM_TYPE_ENUM
  amountCurrency?: string
  editIndex: number
  initialCharge?: LocalUsageChargeInput
  alreadyUsedChargeAlertMessage?: string
  currency: CurrencyEnum
  interval: PlanInterval
}

const usageChargeDrawerContentDefaultProps: UsageChargeDrawerContentExtraProps = {
  isCreateMode: false,
  isEdition: false,
  disabled: false,
  isInSubscriptionForm: false,
  showCode: false,
  existingChargeCodes: undefined,
  subscriptionFormType: undefined,
  amountCurrency: undefined,
  editIndex: -1,
  initialCharge: undefined,
  alreadyUsedChargeAlertMessage: undefined,
  currency: CurrencyEnum.Usd,
  interval: PlanInterval.Monthly,
}

export const UsageChargeDrawerContent = withForm({
  defaultValues: DEFAULT_VALUES,
  props: usageChargeDrawerContentDefaultProps,
  render: function UsageChargeDrawerContentRender({
    form,
    isCreateMode,
    isEdition,
    disabled,
    isInSubscriptionForm,
    showCode,
    existingChargeCodes,
    subscriptionFormType,
    amountCurrency,
    editIndex,
    initialCharge,
    alreadyUsedChargeAlertMessage,
    currency,
    interval,
  }) {
    const { translate } = useInternationalization()
    const { open: openPremiumWarningDialog } = usePremiumWarningDialog()
    const { isPremium } = useCurrentUser()
    const { hasAnyPricingUnitConfigured } = useCustomPricingUnits()

    const formValues = useStore(form.store, (state) => state.values)

    // Only disable fields for charges that already exist on the backend (have an id)
    // New charges added to a subscribed plan should remain fully editable
    const isExistingCharge = !!formValues.id
    const isExistingChargeDisabled = disabled && isExistingCharge

    const isCreatePickerScreen = isCreateMode && !formValues.billableMetricId

    const [getBillableMetrics, { data: billableMetricsData }] = useGetBillableMetricsLazyQuery({
      notifyOnNetworkStatusChange: true,
      variables: { limit: 1000 },
    })

    const billableMetricsComboboxData = useMemo(() => {
      const result: ComboboxDataGrouped[] = []

      const collection = billableMetricsData?.billableMetrics?.collection || []

      for (const { id, name, code, recurring } of collection) {
        result.push({
          ...buildCodeComboboxItem({ id, name, code }),
          group: recurring ? 'recurring' : 'metered',
        })
      }

      return result
    }, [billableMetricsData?.billableMetrics?.collection])

    const renderGroupHeader: Record<string, React.ReactNode> = useMemo(
      () => ({
        metered: (
          <Typography variant="captionHl" color="textSecondary">
            {translate('text_177273892183648ke5pdrlvc')}
          </Typography>
        ),
        recurring: (
          <Typography variant="captionHl" color="textSecondary">
            {translate('text_1772738921836t0afm4rguui')}
          </Typography>
        ),
      }),
      [translate],
    )

    const {
      getUsageChargeModelComboboxData,
      getIsPayInAdvanceOptionDisabledForUsageCharge,
      getIsProRatedOptionDisabledForUsageCharge,
    } = useChargeForm()

    const chargeModelComboboxData = useMemo(
      () =>
        getUsageChargeModelComboboxData({
          isPremium,
          aggregationType: formValues.billableMetric.aggregationType,
        }),
      [getUsageChargeModelComboboxData, isPremium, formValues.billableMetric.aggregationType],
    )

    const isPayInAdvanceOptionDisabled = useMemo(
      () =>
        getIsPayInAdvanceOptionDisabledForUsageCharge({
          aggregationType: formValues.billableMetric.aggregationType,
          chargeModel: formValues.chargeModel,
          isPayInAdvance: formValues.payInAdvance,
          isProrated: formValues.prorated,
          isRecurring: formValues.billableMetric.recurring,
        }),
      [
        getIsPayInAdvanceOptionDisabledForUsageCharge,
        formValues.billableMetric.aggregationType,
        formValues.billableMetric.recurring,
        formValues.chargeModel,
        formValues.payInAdvance,
        formValues.prorated,
      ],
    )

    const isProratedOptionDisabled = useMemo(
      () =>
        getIsProRatedOptionDisabledForUsageCharge({
          aggregationType: formValues.billableMetric.aggregationType,
          chargeModel: formValues.chargeModel,
          isPayInAdvance: formValues.payInAdvance,
        }),
      [
        getIsProRatedOptionDisabledForUsageCharge,
        formValues.billableMetric.aggregationType,
        formValues.chargeModel,
        formValues.payInAdvance,
      ],
    )

    const chargePricingUnitShortName = useMemo(
      () =>
        (formValues.appliedPricingUnit?.type === LocalPricingUnitType.Custom &&
          formValues.appliedPricingUnit?.shortName) ||
        undefined,
      [formValues.appliedPricingUnit],
    )

    const chargePayInAdvanceDescription = useMemo(() => {
      if (formValues.chargeModel === ChargeModelEnum.Volume) {
        return translate('text_6669b493fae79a0095e639bc')
      } else if (formValues.billableMetric.aggregationType === AggregationTypeEnum.MaxAgg) {
        return translate('text_6669b493fae79a0095e63986')
      } else if (formValues.billableMetric.aggregationType === AggregationTypeEnum.LatestAgg) {
        return translate('text_6669b493fae79a0095e639a1')
      }

      return translate('text_6661fc17337de3591e29e435')
    }, [formValues.chargeModel, formValues.billableMetric.aggregationType, translate])

    const handleChargeModelUpdate = useCallback(
      (name: string, value: unknown) => {
        if (name === 'chargeModel') {
          if (value === form.getFieldValue('chargeModel')) return

          // Check premium gating for graduated percentage
          if (!isPremium && value === ChargeModelEnum.GraduatedPercentage) {
            openPremiumWarningDialog()
            return
          }

          // Reset charge data when switching model — use form.reset to clear all field meta/errors
          form.reset(
            {
              ...form.state.values,
              chargeModel: value as ChargeModelEnum,
              payInAdvance: false,
              prorated: false,
              invoiceable: true,
              properties: getPropertyShape({}),
              filters: [],
              taxes: [],
            },
            { keepDefaultValues: true },
          )
          return
        }

        form.setFieldValue(
          name as keyof UsageChargeDrawerFormValues,
          value as UsageChargeDrawerFormValues[keyof UsageChargeDrawerFormValues],
        )
      },
      [form, isPremium, openPremiumWarningDialog],
    )

    // Filter drawer
    const filterDrawer = useDrawer()
    // Custom charge drawer — opened from CustomCharge via context callback
    const customChargeDrawer = useDrawer()
    const filterEditIndexRef = useRef<number | null>(null)
    const filterOpenCounterRef = useRef(0)

    const filterFormDefaultValuesRef = useRef<ChargeFilterFormValues>({
      chargeModel: ChargeModelEnum.Standard,
      invoiceDisplayName: '',
      properties: getPropertyShape({}),
      values: [],
    })

    const filterForm = useAppForm({
      defaultValues: filterFormDefaultValuesRef.current,
      validationLogic: revalidateLogic(),
      validators: { onDynamic: chargeFilterDrawerSchema },
      onSubmit: ({ value }) => {
        const currentFilters = [...(form.state.values.filters || [])]
        const filterData: LocalChargeFilterInput = {
          invoiceDisplayName: value.invoiceDisplayName || undefined,
          properties: value.properties,
          values: value.values,
        }

        if (filterEditIndexRef.current === null) {
          currentFilters.push(filterData)
        } else {
          currentFilters[filterEditIndexRef.current] = filterData
        }

        form.setFieldValue('filters', currentFilters)
        filterDrawer.close()
      },
    })

    const deleteFilter = (filterIndex: number) => {
      const newFilters = [...(form.state.values.filters || [])]

      newFilters.splice(filterIndex, 1)
      form.setFieldValue('filters', newFilters)
    }

    const openFilterDrawer = (filter?: LocalChargeFilterInput, index?: number) => {
      const isEdit = filter !== undefined && index !== undefined

      filterEditIndexRef.current = isEdit ? index : null

      const filterInitialValues: ChargeFilterFormValues = {
        chargeModel: form.state.values.chargeModel,
        invoiceDisplayName: filter?.invoiceDisplayName || '',
        properties: filter?.properties || getPropertyShape({}),
        values: filter?.values || [],
      }

      const currentFilterIndex =
        filterEditIndexRef.current ?? (form.state.values.filters?.length || 0)

      // Collect values already used by other filters on this charge
      const existingFilterValues = new Set<string>()
      const allFilters = form.state.values.filters || []

      for (let i = 0; i < allFilters.length; i++) {
        if (i === filterEditIndexRef.current) continue

        for (const v of allFilters[i].values) {
          existingFilterValues.add(v)
        }
      }

      // Keep the ref in sync so useAppForm's opts.defaultValues matches the reset values.
      // Without this, useForm's layout effect calls formApi.update(opts) on re-render,
      // which overwrites form values back to the stale opts.defaultValues when !isTouched.
      filterFormDefaultValuesRef.current = filterInitialValues
      filterForm.reset(filterInitialValues)

      // Increment counter so the key changes and React remounts ChargeFilterDrawerContent.
      // NiceModal keeps the drawer mounted between opens — without a fresh key, effects
      // (graduated/volume initialization, validation state) would not re-run.
      filterOpenCounterRef.current++

      filterDrawer.open({
        title: translate(
          isEdit ? 'text_1773687275957yugpyzdyfk1' : 'text_1773687275957id74wq9vyz5',
        ),
        shouldPromptOnClose: () => filterForm.state.isDirty,
        children: (
          <ChargeFilterDrawerProvider
            chargeModel={form.state.values.chargeModel}
            chargeType="usage"
            currency={currency}
            chargePricingUnitShortName={chargePricingUnitShortName}
            isEdition={isEdition || false}
          >
            <ChargeFilterDrawerContent
              key={filterOpenCounterRef.current}
              form={filterForm}
              billableMetricFilters={form.state.values.billableMetric?.filters || []}
              existingFilterValues={existingFilterValues}
              chargeIndex={editIndex}
              filterIndex={currentFilterIndex}
            />
          </ChargeFilterDrawerProvider>
        ),
        actions: (
          <div className="flex w-full items-center justify-between">
            <div>
              {isEdit && (
                <Button
                  variant="quaternary"
                  danger
                  onClick={() => {
                    deleteFilter(index)
                    filterDrawer.close()
                  }}
                >
                  {translate('text_63ea0f84f400488553caa786')}
                </Button>
              )}
            </div>
            <div className="flex gap-3">
              <Button variant="quaternary" onClick={() => filterDrawer.close()}>
                {translate('text_6411e6b530cb47007488b027')}
              </Button>
              <filterForm.Subscribe
                selector={(state: { canSubmit: boolean; isSubmitting: boolean }) => ({
                  canSubmit: state.canSubmit,
                  isSubmitting: state.isSubmitting,
                })}
              >
                {({ canSubmit, isSubmitting }: { canSubmit: boolean; isSubmitting: boolean }) => (
                  <Button
                    data-test="charge-filter-drawer-save"
                    disabled={!canSubmit || isSubmitting}
                    loading={isSubmitting}
                    onClick={() => filterForm.handleSubmit()}
                  >
                    {translate(
                      isEdit ? 'text_17295436903260tlyb1gp1i7' : 'text_66ab42d4ece7e6b7078993b9',
                    )}
                  </Button>
                )}
              </filterForm.Subscribe>
            </div>
          </div>
        ),
      })

      // Auto-click the "Add key value" button so the filter combobox is shown immediately
      if (!isEdit) {
        setTimeout(() => {
          document
            .getElementById(buildChargeFilterAddFilterButtonId(editIndex, currentFilterIndex))
            ?.click()
        }, DRAWER_TRANSITION_DURATION + 150)
      }
    }

    const customChargeForm = useAppForm({
      defaultValues: { customProperties: '' as string | undefined },
      validators: {
        onDynamic: z.object({ customProperties: z.string().min(1) }),
      },
      onSubmit: ({ value }) => {
        if (value.customProperties) {
          form.setFieldValue('properties.customProperties', value.customProperties)
          customChargeDrawer.close()
        }
      },
    })

    const openCustomChargeDrawer = (currentValue: string | undefined) => {
      customChargeForm.reset({ customProperties: currentValue }, { keepDefaultValues: true })

      customChargeDrawer.open({
        title: translate('text_663dea5702b60301d8d0646e'),
        shouldPromptOnClose: () => customChargeForm.state.isDirty,
        onClose: () => customChargeForm.reset(),
        children: (
          <CenteredPage.SectionWrapper>
            <CenteredPage.PageTitle
              title={translate('text_663dea5702b60301d8d0646e')}
              description={translate('text_663dea5702b60301d8d064fe')}
            />

            <Card>
              <Typography variant="subhead1">
                {translate('text_663dea5702b60301d8d06502')}
              </Typography>
              <JsonEditor
                hideLabel
                label={translate('text_663dea5702b60301d8d06502')}
                value={currentValue}
                onChange={(value) => customChargeForm.setFieldValue('customProperties', value)}
                onBlur={() => {}}
              />
            </Card>
          </CenteredPage.SectionWrapper>
        ),
        actions: (
          <div className="flex justify-end gap-3">
            <Button variant="quaternary" onClick={() => customChargeDrawer.close()}>
              {translate('text_6411e6b530cb47007488b027')}
            </Button>
            <customChargeForm.Subscribe selector={({ canSubmit }) => canSubmit}>
              {(canSubmit) => (
                <Button
                  disabled={!canSubmit}
                  onClick={() => customChargeForm.handleSubmit()}
                  data-test="custom-charge-drawer-save"
                >
                  {translate('text_663dea5702b60301d8d06490')}
                </Button>
              )}
            </customChargeForm.Subscribe>
          </div>
        ),
      })
    }

    return (
      <CenteredPage.SectionWrapper>
        <CenteredPage.PageTitle
          title={translate('text_177213328514118gjrdaqs8s')}
          description={translate('text_1772133285142lsyz4j6nrai')}
        />

        {isCreatePickerScreen ? (
          <CenteredPage.PageSection>
            <CenteredPage.PageSectionTitle
              title={translate('text_1772133285142iljykq4wpq5')}
              description={translate('text_1772738921836y4nmj2wms6b')}
            />

            <form.AppField
              name="billableMetricId"
              listeners={{
                onChange: ({ value }: { value: string }) => {
                  const allBms = [...(billableMetricsData?.billableMetrics?.collection || [])]
                  const selectedBm = allBms.find((bm) => bm.id === value)

                  if (selectedBm) {
                    form.setFieldValue('billableMetric', selectedBm)
                    form.setFieldValue('properties', getPropertyShape({}))
                    form.setFieldValue('filters', selectedBm.filters?.length ? [] : undefined)

                    seedChargeCode({
                      enabled: !!showCode && isCreateMode,
                      sourceCode: selectedBm.code,
                      existingChargeCodes,
                      setCode: (nextCode) => form.setFieldValue('code', nextCode),
                    })

                    if (hasAnyPricingUnitConfigured && amountCurrency) {
                      form.setFieldValue('appliedPricingUnit', {
                        code: amountCurrency,
                        conversionRate: undefined,
                        shortName: amountCurrency,
                        type: LocalPricingUnitType.Fiat,
                      } as LocalPricingUnitInput)
                    }
                  }
                },
              }}
            >
              {(field) => (
                <field.ComboBoxField
                  className={SEARCH_BILLABLE_METRIC_IN_USAGE_CHARGE_DRAWER_INPUT_CLASSNAME}
                  data={billableMetricsComboboxData}
                  searchQuery={getBillableMetrics}
                  loading={false}
                  placeholder={translate('text_6435888d7cc86500646d8981')}
                  emptyText={translate('text_6246b6bc6b25f500b779aa7a')}
                  renderGroupHeader={renderGroupHeader}
                />
              )}
            </form.AppField>
          </CenteredPage.PageSection>
        ) : (
          <CenteredPage.SubsectionWrapper>
            {/* Selected billable metric (read-only) */}
            <CenteredPage.PageSection>
              <CenteredPage.PageSectionTitle title={translate('text_1772133285142iljykq4wpq5')} />

              <Selector
                icon="pulse"
                title={formValues.billableMetric.name}
                subtitle={formValues.billableMetric.code}
              />

              {showCode && (
                <ChargeCodeField
                  form={form}
                  fields={{ code: 'code' }}
                  disabled={isInSubscriptionForm || isExistingChargeDisabled}
                />
              )}
            </CenteredPage.PageSection>

            {/* Pricing unit settings */}
            {!!hasAnyPricingUnitConfigured && (
              <CenteredPage.PageSection>
                <CenteredPage.PageSectionTitle title={translate('text_17502574817266uy9bvk3i8u')} />

                <CustomPricingUnitSelector
                  currency={currency}
                  isInSubscriptionForm={isInSubscriptionForm}
                  disabled={isExistingChargeDisabled}
                  localCharge={formValues as unknown as LocalUsageChargeInput}
                  handleUpdate={handleChargeModelUpdate}
                />
              </CenteredPage.PageSection>
            )}

            {/* Pricing settings */}
            <CenteredPage.PageSection>
              <CenteredPage.PageSectionTitle title={translate('text_1772133285141xbpuxbd4vrk')} />

              <ChargeModelSelector
                alreadyUsedChargeAlertMessage={alreadyUsedChargeAlertMessage}
                isInSubscriptionForm={isInSubscriptionForm}
                disabled={isExistingChargeDisabled}
                localCharge={formValues as unknown as LocalUsageChargeInput}
                chargeModelComboboxData={chargeModelComboboxData}
                handleUpdate={handleChargeModelUpdate}
              />

              <ChargeWrapperSwitch
                chargeType="usage"
                chargePricingUnitShortName={chargePricingUnitShortName}
                currency={currency}
                form={form}
                isEdition={isEdition || false}
                localCharge={formValues as unknown as LocalUsageChargeInput}
                propertyCursor="properties"
                onExpandCustomCharge={openCustomChargeDrawer}
              />

              {!!formValues.billableMetric?.filters?.length && (
                <CenteredPage.SubsectionTitle
                  title={translate('text_66ab42d4ece7e6b7078993ad')}
                  description={translate('text_17732575346321t54t9g8ok5')}
                />
              )}

              {!!formValues.filters?.length && (
                <VirtualFilterList
                  className="flex flex-col gap-4"
                  gap={16}
                  items={formValues.filters}
                  estimateItemHeight={76}
                  getItemKey={(_filter, filterIndex) => `filter-selector-${filterIndex}`}
                  renderItem={(filter, filterIndex) => {
                    const displayValues = filter.values
                      .map((value: string) => {
                        try {
                          const [k, v] = Object.entries(JSON.parse(value))[0]

                          return v === ALL_FILTER_VALUES ? `${k}` : `${v}`
                        } catch {
                          return value
                        }
                      })
                      .join(' \u2022 ')

                    return (
                      <Selector
                        data-test={`filter-charge-selector-${filterIndex}`}
                        icon="filter"
                        title={
                          filter.invoiceDisplayName ||
                          displayValues ||
                          translate('text_65f847a944603a01034f5831')
                        }
                        subtitle={filter.invoiceDisplayName ? displayValues : undefined}
                        endContent={
                          <Button icon="chevron-right-filled" variant="quaternary" tabIndex={-1} />
                        }
                        hoverActions={
                          <SelectorActions
                            actions={[
                              {
                                icon: 'trash',
                                tooltipCopy: translate('text_63aa085d28b8510cd46443ff'),
                                onClick: (e) => {
                                  e.stopPropagation()
                                  deleteFilter(filterIndex)
                                },
                              },
                              {
                                icon: 'pen',
                                tooltipCopy: translate('text_1773687275957yugpyzdyfk1'),
                                onClick: () => openFilterDrawer(filter, filterIndex),
                              },
                            ]}
                          />
                        }
                        onClick={() => openFilterDrawer(filter, filterIndex)}
                      />
                    )
                  }}
                />
              )}

              {/* Add filter */}
              {!!formValues.billableMetric?.filters?.length && (
                <Button
                  data-test="add-charge-filter"
                  fitContent
                  align="left"
                  variant="inline"
                  startIcon="plus"
                  onClick={() => openFilterDrawer()}
                >
                  {translate('text_65f8472df7593301061e27e2')}
                </Button>
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
                description={chargePayInAdvanceDescription}
                disabled={isInSubscriptionForm || isExistingChargeDisabled}
                isPayInAdvanceOptionDisabled={isPayInAdvanceOptionDisabled}
                onPayInAdvanceChange={(payInAdvance) => {
                  if (!payInAdvance) {
                    form.setFieldValue('invoiceable', true)
                    form.setFieldValue('regroupPaidFees', null)
                  }
                }}
              />

              {formValues.payInAdvance && (
                <ChargeInvoicingStrategyOption
                  localCharge={formValues as unknown as LocalUsageChargeInput}
                  disabled={isInSubscriptionForm || isExistingChargeDisabled}
                  openPremiumDialog={() => openPremiumWarningDialog()}
                  handleUpdate={({ regroupPaidFees, invoiceable }) => {
                    form.setFieldValue('regroupPaidFees', regroupPaidFees)
                    form.setFieldValue('invoiceable', invoiceable)
                  }}
                />
              )}

              {!!formValues.billableMetric.recurring && (
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
                          isInSubscriptionForm ||
                          isExistingChargeDisabled ||
                          isProratedOptionDisabled
                        }
                        subLabel={
                          isProratedOptionDisabled
                            ? translate('text_649c54823c9089006247625a', {
                                chargeModel: translate(
                                  chargeModelLookupTranslation[formValues.chargeModel],
                                ),
                              })
                            : ''
                        }
                      />
                    )}
                  </form.AppField>
                </div>
              )}

              {!formValues.payInAdvance && (
                <div className="flex flex-col gap-4">
                  <div className="flex flex-col gap-1">
                    <Typography variant="captionHl" color="textSecondary">
                      {translate('text_643e592657fc1ba5ce110c30')}
                    </Typography>
                    <Typography variant="caption">
                      {translate('text_6661fc17337de3591e29e451', {
                        interval: translate(
                          mapChargeIntervalCopy(interval, false),
                        ).toLocaleLowerCase(),
                      })}
                    </Typography>
                  </div>

                  <SpendingMinimumOptionSection
                    initialLocalCharge={
                      (initialCharge || formValues) as unknown as LocalUsageChargeInput
                    }
                    subscriptionFormType={subscriptionFormType}
                    disabled={isExistingChargeDisabled}
                    localCharge={formValues as unknown as LocalUsageChargeInput}
                    chargePricingUnitShortName={chargePricingUnitShortName}
                    currency={currency}
                    isPremium={isPremium}
                    chargeIndex={editIndex}
                    handleUpdate={(name, value) => {
                      form.setFieldValue(
                        name as keyof UsageChargeDrawerFormValues,
                        value as UsageChargeDrawerFormValues[keyof UsageChargeDrawerFormValues],
                      )
                    }}
                    handleRemoveSpendingMinimum={() => {
                      form.setFieldValue('minAmountCents', '')
                    }}
                  />
                </div>
              )}

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
