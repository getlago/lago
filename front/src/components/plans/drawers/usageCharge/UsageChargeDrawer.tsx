import { gql } from '@apollo/client'
import { revalidateLogic } from '@tanstack/react-form'
import { forwardRef, useImperativeHandle, useRef } from 'react'
import { z } from 'zod'

import { Button } from '~/components/designSystem/Button'
import { useFormDrawer } from '~/components/drawers/useDrawer'
import { focusFirstInput } from '~/components/drawers/useFocusTrap'
import {
  applyExistingCodeError,
  buildChargeCodeSchema,
} from '~/components/plans/drawers/common/chargeCode'
import { RemoveChargeWarningDialogRef } from '~/components/plans/RemoveChargeWarningDialog'
import {
  LocalChargeFilterInput,
  LocalPricingUnitInput,
  LocalPricingUnitType,
  LocalUsageChargeInput,
} from '~/components/plans/types'
import { PlanFormProvider, usePlanFormContext } from '~/contexts/PlanFormContext'
import { useDuplicatePlanVar } from '~/core/apolloClient'
import {
  FORM_ERRORS_ENUM,
  FORM_TYPE_ENUM,
  MUI_INPUT_BASE_ROOT_CLASSNAME,
  SEARCH_BILLABLE_METRIC_IN_USAGE_CHARGE_DRAWER_INPUT_CLASSNAME,
} from '~/core/constants/form'
import getPropertyShape from '~/core/serializers/getPropertyShape'
import {
  PropertiesZodInput,
  validateChargeProperties,
} from '~/formValidation/chargePropertiesSchema'
import {
  BillableMetricForPlanFragment,
  ChargeModelEnum,
  CustomChargeFragmentDoc,
  GraduatedChargeFragmentDoc,
  GraduatedPercentageChargeFragmentDoc,
  PackageChargeFragmentDoc,
  PercentageChargeFragmentDoc,
  PresentationGroupKeysFragmentDoc,
  PricingGroupKeysFragmentDoc,
  RegroupPaidFeesEnum,
  StandardChargeFragmentDoc,
  TaxForTaxesSelectorSectionFragmentDoc,
  VolumeRangesFragmentDoc,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

import { DEFAULT_VALUES } from './constants'
import { UsageChargeDrawerContent } from './UsageChargeDrawerContent'

gql`
  fragment BillableMetricForUsageChargeSection on BillableMetric {
    id
    name
    code
    aggregationType
    recurring
    filters {
      id
      key
      values
    }
  }

  query getBillableMetrics($page: Int, $limit: Int, $searchTerm: String) {
    billableMetrics(page: $page, limit: $limit, searchTerm: $searchTerm) {
      collection {
        id
        ...BillableMetricForUsageChargeSection
      }
    }
  }

  fragment UsageChargeForDrawer on Charge {
    id
    chargeModel
    invoiceable
    minAmountCents
    payInAdvance
    prorated
    invoiceDisplayName
    regroupPaidFees
    properties {
      graduatedRanges {
        ...GraduatedCharge
      }
      graduatedPercentageRanges {
        ...GraduatedPercentageCharge
      }
      volumeRanges {
        ...VolumeRanges
      }
      ...PackageCharge
      ...StandardCharge
      ...PercentageCharge
      ...CustomCharge
      ...PricingGroupKeys
      ...PresentationGroupKeys
    }
    filters {
      invoiceDisplayName
      values
      properties {
        graduatedRanges {
          ...GraduatedCharge
        }
        graduatedPercentageRanges {
          ...GraduatedPercentageCharge
        }
        volumeRanges {
          ...VolumeRanges
        }
        ...PackageCharge
        ...StandardCharge
        ...PercentageCharge
        ...CustomCharge
        ...PricingGroupKeys
      }
    }
    billableMetric {
      id
      name
      aggregationType
      recurring
      filters {
        key
        values
      }
    }
    taxes {
      ...TaxForTaxesSelectorSection
    }
  }

  ${GraduatedChargeFragmentDoc}
  ${GraduatedPercentageChargeFragmentDoc}
  ${VolumeRangesFragmentDoc}
  ${PackageChargeFragmentDoc}
  ${StandardChargeFragmentDoc}
  ${PercentageChargeFragmentDoc}
  ${CustomChargeFragmentDoc}
  ${PricingGroupKeysFragmentDoc}
  ${PresentationGroupKeysFragmentDoc}
  ${TaxForTaxesSelectorSectionFragmentDoc}
`

// `code` is only required when the field is shown (v2 details/edition via
// `showCode`); the legacy plan form keeps it optional so its hidden, empty code
// never blocks submit.
const buildUsageChargeDrawerSchema = (requireCode: boolean) =>
  z
    .object({
      billableMetricId: z.string().min(1, { message: 'text_624ea7c29103fd010732ab7d' }),
      billableMetric: z.custom<BillableMetricForPlanFragment>(),
      appliedPricingUnit: z.custom<LocalPricingUnitInput>().optional(),
      chargeModel: z.enum(ChargeModelEnum),
      code: buildChargeCodeSchema(requireCode),
      id: z.string().optional(),
      invoiceDisplayName: z.string(),
      invoiceable: z.boolean(),
      minAmountCents: z.string(),
      payInAdvance: z.boolean(),
      prorated: z.boolean(),
      properties: z.record(z.string(), z.unknown()).optional(),
      filters: z.custom<LocalChargeFilterInput[]>().optional(),
      regroupPaidFees: z.string().nullable(),
      taxes: z.array(
        z.object({ id: z.string(), code: z.string(), name: z.string(), rate: z.number() }),
      ),
    })
    .superRefine((data, ctx) => {
      // Validate default properties (always required, even when filters are present)
      if (data.properties) {
        validateChargeProperties(data.chargeModel, data.properties, ctx, ['properties'])
      }

      // Validate filter properties and filter values
      if (data.filters?.length) {
        for (let fi = 0; fi < data.filters.length; fi++) {
          validateChargeProperties(
            data.chargeModel,
            data.filters[fi].properties as PropertiesZodInput,
            ctx,
            ['filters', String(fi), 'properties'],
          )

          if (!data.filters[fi].values?.length) {
            ctx.addIssue({
              code: 'custom',
              message: '',
              path: ['filters', String(fi), 'values'],
            })
          }
        }
      }

      // Validate appliedPricingUnit conversion rate when custom
      if (
        data.appliedPricingUnit?.type === LocalPricingUnitType.Custom &&
        (!data.appliedPricingUnit.conversionRate ||
          Number(data.appliedPricingUnit.conversionRate || 0) <= 0)
      ) {
        ctx.addIssue({
          code: 'custom',
          message: '',
          path: ['appliedPricingUnit', 'conversionRate'],
        })
      }
    })

// Backward-compatible export (code optional) - kept for existing safeParse tests.
export const usageChargeDrawerSchema = buildUsageChargeDrawerSchema(false)

const USAGE_CHARGE_FORM_ID = 'usage-charge-drawer-form'

export interface UsageChargeDrawerRef {
  openDrawer: (
    charge?: LocalUsageChargeInput,
    index?: number,
    options?: {
      alreadyUsedChargeAlertMessage?: string
      initialCharge?: LocalUsageChargeInput
      isUsedInSubscription?: boolean
    },
  ) => void
  closeDrawer: () => void
}

interface UsageChargeDrawerProps {
  disabled?: boolean
  isEdition?: boolean
  isInSubscriptionForm?: boolean
  // TEMP (LAGO-1498): drop showCode + existingChargeCodes once the old
  // plan/subscription forms are retired and the Code field becomes unconditional.
  showCode?: boolean
  existingChargeCodes?: (string | null | undefined)[]
  subscriptionFormType?: keyof typeof FORM_TYPE_ENUM
  onSave: (
    charge: LocalUsageChargeInput,
    index: number | null,
  ) =>
    | void
    | boolean
    | FORM_ERRORS_ENUM.existingCode
    | Promise<void | boolean | FORM_ERRORS_ENUM.existingCode>
  onDelete?: (index: number) => void
  removeChargeWarningDialogRef?: React.RefObject<RemoveChargeWarningDialogRef>
  amountCurrency?: string
}

// ---------------------------------------------------------------------------
// Drawer wrapper - thin shell that manages form + drawer lifecycle
// ---------------------------------------------------------------------------

export const UsageChargeDrawer = forwardRef<UsageChargeDrawerRef, UsageChargeDrawerProps>(
  (
    {
      disabled,
      isEdition,
      isInSubscriptionForm,
      showCode = false,
      existingChargeCodes,
      subscriptionFormType,
      onSave,
      onDelete,
      removeChargeWarningDialogRef,
      amountCurrency,
    },
    ref,
  ) => {
    const { translate } = useInternationalization()
    const { currency, interval } = usePlanFormContext()
    const { type: actionType } = useDuplicatePlanVar()
    const chargeDrawer = useFormDrawer()
    const editIndexRef = useRef<number>(-1)
    const alertMessageRef = useRef<string | undefined>(undefined)
    const initialChargeRef = useRef<LocalUsageChargeInput | undefined>(undefined)
    const isCreateModeRef = useRef(false)
    const isUsedInSubscriptionRef = useRef(false)
    const shouldFocusComboBoxRef = useRef(false)

    const form = useAppForm({
      defaultValues: DEFAULT_VALUES,
      validationLogic: revalidateLogic(),
      validators: {
        onDynamic: buildUsageChargeDrawerSchema(showCode),
      },
      onSubmit: async ({ value, formApi }) => {
        const localCharge: LocalUsageChargeInput = {
          billableMetric: value.billableMetric,
          appliedPricingUnit: value.appliedPricingUnit,
          chargeModel: value.chargeModel,
          code: value.code || undefined,
          id: value.id,
          invoiceDisplayName: value.invoiceDisplayName || undefined,
          invoiceable: value.invoiceable,
          minAmountCents: value.minAmountCents || undefined,
          payInAdvance: value.payInAdvance,
          prorated: value.prorated,
          properties: value.properties,
          filters: value.filters,
          regroupPaidFees: (value.regroupPaidFees as RegroupPaidFeesEnum) || undefined,
          taxes: value.taxes,
        }

        const result = await onSave(
          localCharge,
          isCreateModeRef.current ? null : editIndexRef.current,
        )

        // Backend rejected a duplicate code: surface it under the Code input
        // (same pattern as plan-settings code) and keep the drawer open.
        if (result === FORM_ERRORS_ENUM.existingCode) {
          applyExistingCodeError(formApi)
          return
        }

        if (result !== false) {
          chargeDrawer.close()
        }
      },
    })

    const openChargeDrawer = () => {
      const showDelete = !isCreateModeRef.current && !isInSubscriptionForm && !!onDelete

      const handleDelete = () => {
        const deleteCharge = () => {
          onDelete?.(editIndexRef.current)
        }

        chargeDrawer.close()

        if (actionType !== 'duplicate' && isUsedInSubscriptionRef.current) {
          removeChargeWarningDialogRef?.current?.openDialog({ callback: deleteCharge })
        } else {
          deleteCharge()
        }
      }

      chargeDrawer.open({
        title: translate('text_177213328514118gjrdaqs8s'),
        form: { id: USAGE_CHARGE_FORM_ID, submit: form.handleSubmit },
        closeOnSubmitSuccess: false,
        shouldPromptOnClose: () => form.state.isDirty,
        onClose: () => form.reset(),
        onEntered: (container) => {
          if (shouldFocusComboBoxRef.current) {
            shouldFocusComboBoxRef.current = false
            container
              .querySelector<HTMLElement>(
                `.${SEARCH_BILLABLE_METRIC_IN_USAGE_CHARGE_DRAWER_INPUT_CLASSNAME} .${MUI_INPUT_BASE_ROOT_CLASSNAME}`,
              )
              ?.click()

            return
          }

          focusFirstInput(container)
        },
        children: (
          <PlanFormProvider currency={currency} interval={interval}>
            <UsageChargeDrawerContent
              form={form}
              isCreateMode={isCreateModeRef.current}
              isEdition={isEdition}
              disabled={disabled}
              isInSubscriptionForm={isInSubscriptionForm}
              showCode={showCode}
              existingChargeCodes={existingChargeCodes}
              subscriptionFormType={subscriptionFormType}
              amountCurrency={amountCurrency}
              editIndex={editIndexRef.current}
              initialCharge={initialChargeRef.current}
              alreadyUsedChargeAlertMessage={alertMessageRef.current}
              currency={currency}
              interval={interval}
            />
          </PlanFormProvider>
        ),
        secondaryAction: showDelete ? (
          <Button danger variant="quaternary" onClick={handleDelete}>
            {translate('text_63ea0f84f400488553caa786')}
          </Button>
        ) : undefined,
        mainAction: (
          <form.AppForm>
            <form.SubmitButton dataTest="usage-charge-drawer-save">
              {translate(
                isCreateModeRef.current
                  ? 'text_1775225915209vpdyh1dvrm5'
                  : 'text_17295436903260tlyb1gp1i7',
              )}
            </form.SubmitButton>
          </form.AppForm>
        ),
      })
    }

    useImperativeHandle(ref, () => ({
      openDrawer: (charge?, index?, options?) => {
        if (charge && index !== undefined) {
          // Edit mode
          isCreateModeRef.current = false
          editIndexRef.current = index
          alertMessageRef.current = options?.alreadyUsedChargeAlertMessage
          initialChargeRef.current = options?.initialCharge || charge
          isUsedInSubscriptionRef.current = options?.isUsedInSubscription || false
          form.reset(
            {
              billableMetricId: charge.billableMetric.id,
              billableMetric: charge.billableMetric,
              appliedPricingUnit: charge.appliedPricingUnit,
              chargeModel: charge.chargeModel,
              code: charge.code || '',
              id: charge.id,
              invoiceDisplayName: charge.invoiceDisplayName || '',
              invoiceable: charge.invoiceable ?? true,
              minAmountCents: charge.minAmountCents || '',
              payInAdvance: charge.payInAdvance || false,
              prorated: charge.prorated || false,
              properties: charge.properties || getPropertyShape({}),
              filters: charge.filters || [],
              regroupPaidFees: charge.regroupPaidFees || null,
              taxes: charge.taxes || [],
            },
            { keepDefaultValues: true },
          )
        } else {
          // Create mode
          isCreateModeRef.current = true
          editIndexRef.current = -1
          alertMessageRef.current = undefined
          initialChargeRef.current = undefined
          isUsedInSubscriptionRef.current = false
          form.reset(DEFAULT_VALUES, { keepDefaultValues: true })
          shouldFocusComboBoxRef.current = true
        }

        openChargeDrawer()
      },
      closeDrawer: () => {
        chargeDrawer.close()
      },
    }))

    return null
  },
)

UsageChargeDrawer.displayName = 'UsageChargeDrawer'
