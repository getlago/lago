import { gql } from '@apollo/client'
import InputAdornment from '@mui/material/InputAdornment'
import { useFormik } from 'formik'
import { tw } from 'lago-design-system'
import { forwardRef, useCallback, useImperativeHandle, useMemo, useRef, useState } from 'react'
import { number, object, string } from 'yup'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { Drawer, DrawerRef } from '~/components/designSystem/Drawer'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { AmountInputField, ComboBox, ComboBoxField, TextInputField } from '~/components/form'
import { DrawerLayout } from '~/components/layouts/Drawer'
import { ALL_CHARGE_MODELS, ALL_FILTER_VALUES } from '~/core/constants/form'
import { TExtendedRemainingFee } from '~/core/formats/formatInvoiceItemsMap'
import { getCurrencySymbol, intlFormatNumber } from '~/core/formats/intlFormatNumber'
import {
  AdjustedFeeTypeEnum,
  Charge,
  ChargeModelEnum,
  CreateAdjustedFeeInput,
  CurrencyEnum,
  FeeForCreateFeeDrawerFragment,
  FixedCharge,
  FixedChargeChargeModelEnum,
  useCreateAdjustedFeeMutation,
  useGetInvoiceDetailsForCreateFeeDrawerQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { OnRegeneratedFeeAdd } from '~/pages/CustomerInvoiceRegenerate'

import { InvoiceTableSection } from './InvoiceDetailsTable'
import { InvoiceDetailsTableBodyLine } from './InvoiceDetailsTableBodyLine'
import {
  getChargesComboboxDataFromInvoiceSubscription,
  getChargesFiltersComboboxDataFromInvoiceSubscription,
} from './utils'

const isChargeModelUnitAdjustmentDisabled = (
  chargeModel?: ChargeModelEnum | FixedChargeChargeModelEnum,
  prorated?: boolean,
): boolean => {
  if (!chargeModel) return false

  return !!(
    chargeModel === ALL_CHARGE_MODELS.Percentage ||
    chargeModel === ALL_CHARGE_MODELS.Dynamic ||
    (chargeModel === ALL_CHARGE_MODELS.Graduated && prorated)
  )
}

const calculateTotalAmount = (
  units?: number | string | null,
  unitAmount?: number | string | null,
) => {
  return Number(units || 0) * Number(unitAmount || 0)
}

gql`
  # Fragment for subscription/plan data (charges and fixed charges available to add)
  fragment SubscriptionForCreateFeeDrawer on Subscription {
    id
    plan {
      id
      charges {
        id
        invoiceDisplayName
        chargeModel
        prorated
        properties {
          amount
        }
        filters {
          id
          invoiceDisplayName
          values
        }
        billableMetric {
          id
          name
          code
        }
      }
      fixedCharges {
        id
        invoiceDisplayName
        chargeModel
        prorated
        addOn {
          id
          name
          code
        }
      }
    }
  }

  # Fee fragment for the drawer - matches InvoiceForFormatInvoiceItemMap structure
  # so fees can be used consistently for boundary grouping
  fragment FeeForCreateFeeDrawer on Fee {
    id
    adjustedFee
    properties {
      fromDatetime
      toDatetime
    }
    subscription {
      id
    }
    charge {
      id
      filters {
        id
        values
      }
      properties {
        graduatedRanges {
          flatAmount
          fromValue
          perUnitAmount
          toValue
        }
        graduatedPercentageRanges {
          flatAmount
          fromValue
          rate
          toValue
        }
      }
    }
    fixedCharge {
      id
    }
    chargeFilter {
      id
    }
    pricingUnitUsage {
      shortName
    }
  }

  fragment FeeForEditfeeDrawer on Fee {
    id
    currency
    charge {
      id
      chargeModel
      prorated
    }
    fixedCharge {
      id
      chargeModel
      prorated
    }
  }

  query getInvoiceDetailsForCreateFeeDrawer($invoiceId: ID!) {
    invoice(id: $invoiceId) {
      id
      subscriptions {
        ...SubscriptionForCreateFeeDrawer
      }
      # Fees at Invoice level (like InvoiceForFormatInvoiceItemMap)
      fees {
        ...FeeForCreateFeeDrawer
      }
    }
  }

  mutation createAdjustedFee($input: CreateAdjustedFeeInput!) {
    createAdjustedFee(input: $input) {
      id
    }
  }
`

type EditFeeDrawerProps =
  | {
      mode: 'edit'
      invoiceId: string
      fee: TExtendedRemainingFee
    }
  | {
      mode: 'regenerate'
      invoiceId: string
      invoiceSubscriptionId: string
      fee?: TExtendedRemainingFee
      onAdd: OnRegeneratedFeeAdd
      localFees?: FeeForCreateFeeDrawerFragment[]
    }
  | {
      mode: 'add'
      invoiceId: string
      invoiceSubscriptionId: string
    }

export interface EditFeeDrawerRef {
  openDrawer: (data: EditFeeDrawerProps) => unknown
  closeDrawer: () => unknown
}

type formikValues = Omit<Partial<CreateAdjustedFeeInput>, 'feeId'> & {
  adjustmentType?: AdjustedFeeTypeEnum.AdjustedAmount | AdjustedFeeTypeEnum.AdjustedUnits
}

export const EditFeeDrawer = forwardRef<EditFeeDrawerRef>((_, ref) => {
  const { translate } = useInternationalization()
  const drawerRef = useRef<DrawerRef>(null)
  const [localData, setLocalData] = useState<EditFeeDrawerProps | undefined>(undefined)
  const isRegenerateMode = localData?.mode === 'regenerate'
  const isEditMode = localData?.mode === 'edit'
  const isAddMode = localData?.mode === 'add'
  const fee = isEditMode || isRegenerateMode ? localData?.fee : undefined
  const localFees = isRegenerateMode ? localData.localFees : undefined
  const currency = fee?.currency || CurrencyEnum.Usd
  const pricingUnitUsage = fee?.pricingUnitUsage

  const resetForm = () => {
    formikProps.resetForm()
    formikProps.validateForm()
  }

  const invoiceSubscriptionId =
    isRegenerateMode || isAddMode ? localData.invoiceSubscriptionId : undefined

  const {
    loading: invoiceLoading,
    data: invoiceData,
    refetch: refetchInvoiceDetailsForCreateFeeDrawer,
  } = useGetInvoiceDetailsForCreateFeeDrawerQuery({
    variables: {
      invoiceId: localData?.invoiceId || '',
    },
    skip: !localData?.invoiceId,
    // Prevent this query from polluting the Apollo cache with partial fee data
    // which would overwrite the full fee data from getInvoiceFees
    fetchPolicy: 'no-cache',
  })

  const currentSubscription = invoiceData?.invoice?.subscriptions?.find(
    (subscription) => subscription.id === invoiceSubscriptionId,
  )

  // Filter invoice-level fees by subscription ID (matches InvoiceForFormatInvoiceItemMap pattern)
  const subscriptionFees = invoiceData?.invoice?.fees?.filter(
    (f) => f.subscription?.id === invoiceSubscriptionId,
  )

  const [createFee] = useCreateAdjustedFeeMutation({
    onCompleted({ createAdjustedFee }) {
      if (createAdjustedFee?.id) {
        // Close drawer
        drawerRef.current?.closeDrawer()
        resetForm()
      }
    },
    refetchQueries: ['getInvoiceDetails', 'getInvoiceFees'],
  })

  const initialValues = useMemo(() => {
    const values: formikValues = {
      invoiceDisplayName: fee?.invoiceDisplayName || '',
      chargeFilterId: '',
      chargeId: '',
      fixedChargeId: '',
      unitPreciseAmount: undefined,
      units: undefined,
      adjustmentType: undefined,
    }

    if (isRegenerateMode) {
      values.unitPreciseAmount = fee?.preciseUnitAmount?.toString()
      values.units = fee?.units
    }

    return values
  }, [fee, isRegenerateMode])

  const formikProps = useFormik<formikValues>({
    initialValues,
    validationSchema: object().shape({
      invoiceDisplayName: string(),
      chargeFilterId: string(),
      chargeId: string(),
      fixedChargeId: string(),
      unitPreciseAmount: number().test({
        test: function (value, { from }) {
          if (
            from?.[0]?.value?.adjustmentType === AdjustedFeeTypeEnum.AdjustedAmount &&
            !value &&
            Number(value) !== 0
          ) {
            return false
          }

          return true
        },
      }),
      units: number().test({
        test: function (value, { from }) {
          if (!!from?.[0]?.value?.adjustmentType && !value && Number(value) !== 0) {
            return false
          }

          return true
        },
      }),
      adjustmentType: string().required(''),
    }),
    validateOnMount: true,
    enableReinitialize: true,
    onSubmit: async ({ adjustmentType, unitPreciseAmount, units, ...values }) => {
      const chargeFilterId =
        values.chargeFilterId === ALL_FILTER_VALUES ? null : values.chargeFilterId || undefined

      const input: CreateAdjustedFeeInput = {
        chargeFilterId,
        chargeId: values.chargeId,
        feeId: fee?.id,
        fixedChargeId: values.fixedChargeId,
        invoiceDisplayName: values.invoiceDisplayName || undefined,
        invoiceId: localData?.invoiceId || '',

        unitPreciseAmount:
          adjustmentType === AdjustedFeeTypeEnum.AdjustedAmount
            ? String(unitPreciseAmount)
            : undefined,
        units: adjustmentType ? Number(units || 0) : undefined,
      }

      if (isRegenerateMode) {
        const currentCharge = currentSubscription?.plan.charges?.find(
          (charge) => charge.id === values.chargeId,
        )

        const currentFixedCharge = currentSubscription?.plan.fixedCharges?.find(
          (fixedCharge) => fixedCharge.id === values.fixedChargeId,
        )

        localData.onAdd({
          ...(localData.fee || {}),
          ...input,
          invoiceSubscriptionId: invoiceSubscriptionId || '',
          charge: currentCharge as Charge,
          fixedCharge: currentFixedCharge as FixedCharge,
        })

        drawerRef.current?.closeDrawer()
        resetForm()

        return
      }

      await createFee({
        variables: {
          input: {
            ...input,
            subscriptionId: invoiceSubscriptionId || '',
          },
        },
      })
    },
  })

  const setFieldValue = formikProps.setFieldValue

  // Use localFees (from regenerate mode) or subscriptionFees (from invoice query)
  const feesForCombobox = localFees ?? subscriptionFees

  const chargesComboboxData = useMemo(() => {
    return getChargesComboboxDataFromInvoiceSubscription({
      chargesGroupLabel: translate('text_6435888d7cc86500646d8977'),
      fixedChargesGroupLabel: translate('text_176072970726728iw4tc8ucl'),
      subscription: currentSubscription,
      overrideFees: feesForCombobox,
    })
  }, [currentSubscription, translate, feesForCombobox])

  const chargeFiltersComboboxData = useMemo(() => {
    return getChargesFiltersComboboxDataFromInvoiceSubscription({
      defaultFilterOptionLabel: translate('text_64e620bca31226337ffc62ad'),
      subscription: currentSubscription,
      selectedChargeId: formikProps.values.chargeId,
      overrideFees: feesForCombobox,
    })
  }, [currentSubscription, feesForCombobox, formikProps.values.chargeId, translate])

  // Determine if the selected item is a charge or fixed charge
  const selectedItemType = useMemo((): 'charge' | 'fixed-charge' | null => {
    if (fee?.charge || formikProps.values.chargeId) return 'charge'
    if (fee?.fixedCharge || formikProps.values.fixedChargeId) return 'fixed-charge'

    return null
  }, [fee, formikProps.values.chargeId, formikProps.values.fixedChargeId])

  const isChargeFilterIdValid: boolean = useMemo(() => {
    // Fixed charges don't have filters, so they're always valid
    if (selectedItemType === 'fixed-charge') return true

    if (!fee && !!chargeFiltersComboboxData?.length && !formikProps.values.chargeFilterId) {
      return false
    }

    return true
  }, [chargeFiltersComboboxData?.length, fee, formikProps.values.chargeFilterId, selectedItemType])

  const { displayChargeIdField, displayChargeFilterIdField, displayAdjustmentInputs } =
    useMemo(() => {
      const hasChargeFiltersComboboxData = !!chargeFiltersComboboxData?.length
      const isUsageCharge = selectedItemType === 'charge'

      return {
        displayChargeIdField: !fee,
        displayChargeFilterIdField: !fee && isUsageCharge && hasChargeFiltersComboboxData,
        displayAdjustmentInputs:
          !!fee ||
          (hasChargeFiltersComboboxData && isUsageCharge
            ? !!formikProps.values.chargeFilterId
            : !!formikProps.values.chargeId || !!formikProps.values.fixedChargeId),
      }
    }, [
      chargeFiltersComboboxData?.length,
      fee,
      formikProps.values.chargeFilterId,
      formikProps.values.chargeId,
      formikProps.values.fixedChargeId,
      selectedItemType,
    ])

  const isUnitAdjustmentTypeDisabled = useMemo((): boolean => {
    const getChargeConfig = ():
      | { chargeModel?: ChargeModelEnum | FixedChargeChargeModelEnum; prorated?: boolean }
      | undefined => {
      // If we have an existing fee, extract from fee's charge or fixedCharge
      if (fee) {
        const source = fee.charge || fee.fixedCharge

        return source ? { chargeModel: source.chargeModel, prorated: source.prorated } : undefined
      }

      // If we're adding a new fee, find the selected charge or fixed charge
      if (selectedItemType === 'charge') {
        return currentSubscription?.plan.charges?.find(
          (charge) => charge.id === formikProps.values.chargeId,
        )
      }

      if (selectedItemType === 'fixed-charge') {
        return currentSubscription?.plan.fixedCharges?.find(
          (fixedCharge) => fixedCharge.id === formikProps.values.fixedChargeId,
        ) as { chargeModel?: FixedChargeChargeModelEnum; prorated?: boolean } | undefined
      }

      return undefined
    }

    const config = getChargeConfig()

    return !!config && isChargeModelUnitAdjustmentDisabled(config.chargeModel, config.prorated)
  }, [
    currentSubscription,
    fee,
    formikProps.values.chargeId,
    formikProps.values.fixedChargeId,
    selectedItemType,
  ])

  const onChargeIdChange = useCallback(
    (selectedChargeId: string) => {
      const isUsageCharge = currentSubscription?.plan.charges?.find(
        (charge) => charge.id === selectedChargeId,
      )

      const isFixedCharge = currentSubscription?.plan.fixedCharges?.find(
        (fixedCharge) => fixedCharge.id === selectedChargeId,
      )

      if (isUsageCharge) {
        setFieldValue('chargeId', selectedChargeId)
      } else if (isFixedCharge) {
        setFieldValue('fixedChargeId', selectedChargeId)
      }
    },
    [currentSubscription, setFieldValue],
  )

  useImperativeHandle(ref, () => ({
    openDrawer: (data) => {
      setLocalData(data)
      drawerRef.current?.openDrawer()
    },
    closeDrawer: () => {
      drawerRef.current?.closeDrawer()
      resetForm()
    },
  }))

  const feeName = fee?.metadata?.displayName || fee?.itemName || ''
  const drawerTitle = !!fee
    ? translate('text_65a6b4e2cb38d9b70ec53c25', { name: feeName })
    : translate('text_1737709105343hpvidjp0yz0')
  const drawerDescription = !!fee
    ? translate('text_65a6b4e2cb38d9b70ec53c2d')
    : translate('text_1737731953885hprgxewyizj')

  return (
    <Drawer
      showCloseWarningDialog={formikProps.dirty}
      fullContentHeight
      ref={drawerRef}
      withPadding={false}
      title={drawerTitle}
      onClose={resetForm}
      onOpen={() => {
        if (localData?.invoiceId) {
          refetchInvoiceDetailsForCreateFeeDrawer()
        }
      }}
    >
      {({ closeDrawer }) => (
        <DrawerLayout.Wrapper>
          <DrawerLayout.Content>
            {!fee && invoiceLoading ? (
              <div className="flex flex-col gap-12">
                {[...Array(2)].map((__, index) => (
                  <div
                    key={`edit-fee-drawer-loading-block-${index}`}
                    className="flex flex-col gap-1"
                  >
                    <Skeleton variant="text" className="w-40" />
                    <Skeleton variant="text" className="w-80" />
                  </div>
                ))}
              </div>
            ) : (
              <>
                <DrawerLayout.Header title={drawerTitle} description={drawerDescription} />

                {!!fee && (
                  <>
                    <DrawerLayout.Section>
                      <DrawerLayout.SectionTitle
                        title={translate('text_65a6b4e2cb38d9b70ec53c35')}
                        description={translate('text_1737556835239q7202lhbdhk')}
                      />
                      <InvoiceTableSection
                        className={tw(
                          '[&_table>thead>tr>th:nth-child(1)]:w-[45%] [&_table>thead>tr>th:nth-child(1)]:text-left [&_table>thead>tr>th:nth-child(2)]:w-[15%] [&_table>thead>tr>th:nth-child(3)]:w-[20%] [&_table>thead>tr>th:nth-child(4)]:w-[20%]',
                          '[&_table>tbody>tr>td:nth-child(1)]:w-[45%] [&_table>tbody>tr>td:nth-child(1)]:text-left [&_table>tbody>tr>td:nth-child(2)]:w-[15%] [&_table>tbody>tr>td:nth-child(3)]:w-[20%] [&_table>tbody>tr>td:nth-child(4)]:w-[20%]',
                          '[&_table>tbody>tr:last-child>td]:pb-0 [&_table>tbody>tr:last-child>td]:shadow-none [&_table>tbody>tr>td:not(:last-child)]:pr-3 [&_table>thead>tr>th]:pt-0',
                        )}
                      >
                        <table>
                          <thead>
                            <tr>
                              <th>
                                <Typography variant="captionHl" color="grey600">
                                  {translate('text_6388b923e514213fed58331c')}
                                </Typography>
                              </th>
                              <th>
                                <Typography variant="captionHl" color="grey600">
                                  {translate('text_65771fa3f4ab9a00720726ce')}
                                </Typography>
                              </th>
                              <th>
                                <Typography variant="captionHl" color="grey600">
                                  {translate('text_6453819268763979024ad089')}
                                </Typography>
                              </th>
                              <th>
                                <Typography variant="captionHl" color="grey600">
                                  {translate('text_634d631acf4dce7b0127a3a6')}
                                </Typography>
                              </th>
                            </tr>
                          </thead>

                          <tbody>
                            <InvoiceDetailsTableBodyLine
                              canHaveUnitPrice
                              hideVat
                              currency={fee?.currency}
                              displayName={feeName}
                              fee={fee}
                              isDraftInvoice={false}
                            />
                          </tbody>
                        </table>
                      </InvoiceTableSection>
                    </DrawerLayout.Section>
                  </>
                )}
                <DrawerLayout.Section>
                  <DrawerLayout.SectionTitle
                    title={translate('text_65a6b4e2cb38d9b70ec53d31')}
                    description={translate('text_17375568352390mlfarq4p6t')}
                  />

                  <div className="flex flex-col gap-6">
                    {displayChargeIdField && (
                      <ComboBox
                        label={translate('text_1737731953885tbem8s4xo8t')}
                        placeholder={translate('text_1737733582553rmmlatfbk1r')}
                        data={chargesComboboxData}
                        onChange={onChargeIdChange}
                        loading={invoiceLoading}
                        value={
                          formikProps.values.chargeId || formikProps.values.fixedChargeId || ''
                        }
                      />
                    )}

                    {displayChargeFilterIdField && (
                      <ComboBoxField
                        name="chargeFilterId"
                        label={translate('text_66ab42d4ece7e6b7078993ad')}
                        placeholder={translate('text_1737733582553dm4huzkoee6')}
                        formikProps={formikProps}
                        data={chargeFiltersComboboxData}
                      />
                    )}

                    {displayAdjustmentInputs && (
                      <>
                        <TextInputField
                          label={translate('text_65a6b4e2cb38d9b70ec53d39')}
                          name="invoiceDisplayName"
                          placeholder={translate('text_65a6b4e2cb38d9b70ec53d41')}
                          formikProps={formikProps}
                        />

                        <ComboBox
                          label={translate('text_65a6b4e2cb38d9b70ec53d49')}
                          name="adjustmentType"
                          placeholder={translate('text_65a94d976d7a9700716590d9')}
                          data={[
                            {
                              label: translate('text_65a6b4e2cb38d9b70ec53d83'),
                              value: AdjustedFeeTypeEnum.AdjustedAmount,
                            },
                            {
                              label: translate('text_6304e74aab6dbc18d615f3a2'),
                              value: AdjustedFeeTypeEnum.AdjustedUnits,
                              disabled: isUnitAdjustmentTypeDisabled,
                            },
                          ]}
                          value={formikProps.values.adjustmentType}
                          onChange={(newValue) => {
                            const formValues = {
                              ...formikProps.values,
                              adjustmentType: newValue as AdjustedFeeTypeEnum,
                            }

                            // NOTE: During invoice re-generate, we don't want to reset the unitPreciseAmount and units for fee already existing.
                            // Because the fee is already existing and we don't want to lose the data.
                            if (!isRegenerateMode) {
                              formValues.unitPreciseAmount = undefined
                              formValues.units = undefined
                            }

                            formikProps.setValues(formValues)
                          }}
                        />

                        {!!formikProps.values.adjustmentType && (
                          <>
                            <div className="flex items-start gap-4 *:flex-1">
                              <TextInputField
                                label={translate('text_65771fa3f4ab9a00720726ce')}
                                name="units"
                                error={undefined}
                                beforeChangeFormatter={['positiveNumber', 'decimal']}
                                placeholder={translate('text_62a0b7107afa2700a65ef700')}
                                formikProps={formikProps}
                              />

                              {formikProps.values.adjustmentType ===
                                AdjustedFeeTypeEnum.AdjustedAmount && (
                                <>
                                  <AmountInputField
                                    label={translate('text_6453819268763979024ad089')}
                                    name="unitPreciseAmount"
                                    currency={currency}
                                    beforeChangeFormatter={['positiveNumber', 'chargeDecimal']}
                                    placeholder={translate('text_62a0b7107afa2700a65ef700')}
                                    formikProps={formikProps}
                                    error={undefined}
                                    InputProps={{
                                      endAdornment: (
                                        <InputAdornment position="end">
                                          {pricingUnitUsage?.shortName ||
                                            getCurrencySymbol(currency)}
                                        </InputAdornment>
                                      ),
                                    }}
                                  />

                                  <div className="flex flex-col gap-1">
                                    <Typography
                                      className="text-end"
                                      variant="captionHl"
                                      color="grey700"
                                    >
                                      {translate('text_65a6b4e2cb38d9b70ec53d83')}
                                    </Typography>
                                    <div className="flex h-12 flex-col items-end justify-center self-end">
                                      <Typography variant="body" color="grey700">
                                        {intlFormatNumber(
                                          calculateTotalAmount(
                                            formikProps.values.units,
                                            formikProps.values.unitPreciseAmount,
                                          ),
                                          {
                                            currencyDisplay: 'symbol',
                                            currency: currency,
                                            maximumFractionDigits: 15,
                                            pricingUnitShortName: pricingUnitUsage?.shortName,
                                          },
                                        )}
                                      </Typography>

                                      {!!pricingUnitUsage && (
                                        <Typography variant="caption" color="grey600">
                                          {intlFormatNumber(
                                            calculateTotalAmount(
                                              formikProps.values.units,
                                              formikProps.values.unitPreciseAmount,
                                            ) * Number(pricingUnitUsage?.conversionRate || 0),
                                            {
                                              currencyDisplay: 'symbol',
                                              currency: currency,
                                            },
                                          )}
                                        </Typography>
                                      )}
                                    </div>
                                  </div>
                                </>
                              )}
                            </div>

                            {!!fee?.charge && (
                              <Alert type="info">
                                {translate(
                                  formikProps.values.adjustmentType ===
                                    AdjustedFeeTypeEnum.AdjustedAmount
                                    ? 'text_65a6b4e2cb38d9b70ec53d93'
                                    : 'text_6613b48da4efd500cacc44d3',
                                )}
                              </Alert>
                            )}
                          </>
                        )}
                      </>
                    )}
                  </div>
                </DrawerLayout.Section>
              </>
            )}
          </DrawerLayout.Content>

          <DrawerLayout.StickyFooter>
            <Button variant="quaternary" onClick={closeDrawer}>
              {translate('text_6411e6b530cb47007488b027')}
            </Button>

            <Button
              disabled={!formikProps.isValid || !formikProps.dirty || !isChargeFilterIdValid}
              loading={formikProps.isSubmitting}
              onClick={formikProps.submitForm}
            >
              {translate(
                fee?.id ? 'text_65a6b4e2cb38d9b70ec53d9b' : 'text_1752580912616sr615x718w7',
              )}
            </Button>
          </DrawerLayout.StickyFooter>
        </DrawerLayout.Wrapper>
      )}
    </Drawer>
  )
})

EditFeeDrawer.displayName = 'EditFeeDrawer'
