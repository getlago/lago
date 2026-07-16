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
import { LocalFixedChargeInput } from '~/components/plans/types'
import { PlanFormProvider, usePlanFormContext } from '~/contexts/PlanFormContext'
import { useDuplicatePlanVar } from '~/core/apolloClient'
import {
  FORM_ERRORS_ENUM,
  MUI_INPUT_BASE_ROOT_CLASSNAME,
  SEARCH_ADD_ON_IN_FIXED_CHARGE_DRAWER_INPUT_CLASSNAME,
} from '~/core/constants/form'
import getPropertyShape from '~/core/serializers/getPropertyShape'
import { validateChargeProperties } from '~/formValidation/chargePropertiesSchema'
import {
  AddOnForFixedChargesSectionFragment,
  FixedChargeChargeModelEnum,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

import { DEFAULT_VALUES } from './constants'
import { FixedChargeDrawerContent } from './FixedChargeDrawerContent'

export { type FixedChargeDrawerFormValues } from './constants'

const FIXED_CHARGE_FORM_ID = 'fixed-charge-drawer-form'

// `code` is only required when the field is shown (v2 details/edition via
// `showCode`); the legacy plan form keeps it optional so its hidden, empty code
// never blocks submit.
const buildFixedChargeDrawerSchema = (requireCode: boolean) =>
  z
    .object({
      addOnId: z.string().min(1, { message: 'text_624ea7c29103fd010732ab7d' }),
      addOn: z.custom<AddOnForFixedChargesSectionFragment>(),
      applyUnitsImmediately: z.boolean(),
      chargeModel: z.enum(FixedChargeChargeModelEnum),
      code: buildChargeCodeSchema(requireCode),
      id: z.string().optional(),
      invoiceDisplayName: z.string(),
      payInAdvance: z.boolean(),
      properties: z.record(z.string(), z.unknown()),
      prorated: z.boolean(),
      taxes: z.array(
        z.object({ id: z.string(), code: z.string(), name: z.string(), rate: z.number() }),
      ),
      units: z
        .string()
        .min(1, { message: 'text_624ea7c29103fd010732ab7d' })
        .refine((val) => !Number.isNaN(Number(val)), {
          message: 'text_624ea7c29103fd010732ab7d',
        }),
    })
    .superRefine((data, ctx) => {
      validateChargeProperties(data.chargeModel, data.properties, ctx, ['properties'])
    })

export interface FixedChargeDrawerRef {
  openDrawer: (
    charge?: LocalFixedChargeInput,
    index?: number,
    options?: { alreadyUsedChargeAlertMessage?: string; isUsedInSubscription?: boolean },
  ) => void
  closeDrawer: () => void
}

interface FixedChargeDrawerProps {
  disabled?: boolean
  isEdition?: boolean
  isInSubscriptionForm?: boolean
  // TEMP (LAGO-1498): drop showCode + existingChargeCodes once the old
  // plan/subscription forms are retired and the Code field becomes unconditional.
  showCode?: boolean
  existingChargeCodes?: (string | null | undefined)[]
  onSave: (
    charge: LocalFixedChargeInput,
    index: number | null,
  ) =>
    | void
    | boolean
    | FORM_ERRORS_ENUM.existingCode
    | Promise<void | boolean | FORM_ERRORS_ENUM.existingCode>
  onDelete?: (index: number) => void
  removeChargeWarningDialogRef?: React.RefObject<RemoveChargeWarningDialogRef>
}

export const FixedChargeDrawer = forwardRef<FixedChargeDrawerRef, FixedChargeDrawerProps>(
  (
    {
      disabled,
      isEdition,
      isInSubscriptionForm,
      showCode = false,
      existingChargeCodes,
      onSave,
      onDelete,
      removeChargeWarningDialogRef,
    },
    ref,
  ) => {
    const { translate } = useInternationalization()
    const { currency, interval } = usePlanFormContext()
    const { type: actionType } = useDuplicatePlanVar()
    const fixedChargeDrawer = useFormDrawer()
    const editIndexRef = useRef<number>(-1)
    const alertMessageRef = useRef<string | undefined>(undefined)
    const isCreateModeRef = useRef(false)
    const isUsedInSubscriptionRef = useRef(false)
    const shouldFocusComboBoxRef = useRef(false)

    const form = useAppForm({
      defaultValues: DEFAULT_VALUES,
      validationLogic: revalidateLogic(),
      validators: {
        onDynamic: buildFixedChargeDrawerSchema(showCode),
      },
      onSubmit: async ({ value, formApi }) => {
        const localFixedCharge: LocalFixedChargeInput = {
          addOn: value.addOn,
          applyUnitsImmediately: value.applyUnitsImmediately,
          chargeModel: value.chargeModel,
          code: value.code || undefined,
          id: value.id,
          invoiceDisplayName: value.invoiceDisplayName || undefined,
          payInAdvance: value.payInAdvance,
          properties: value.properties,
          prorated: value.prorated,
          taxes: value.taxes,
          units: value.units,
        }

        const result = await onSave(
          localFixedCharge,
          isCreateModeRef.current ? null : editIndexRef.current,
        )

        // Backend rejected a duplicate code: surface it under the Code input
        // (same pattern as plan-settings code) and keep the drawer open.
        if (result === FORM_ERRORS_ENUM.existingCode) {
          applyExistingCodeError(formApi)
          return
        }

        if (result !== false) {
          fixedChargeDrawer.close()
        }
      },
    })

    const openFixedChargeDrawer = () => {
      const showDelete = !isCreateModeRef.current && !isInSubscriptionForm && !!onDelete

      const handleDelete = () => {
        const deleteCharge = () => {
          onDelete?.(editIndexRef.current)
        }

        fixedChargeDrawer.close()

        if (actionType !== 'duplicate' && isUsedInSubscriptionRef.current) {
          removeChargeWarningDialogRef?.current?.openDialog({ callback: deleteCharge })
        } else {
          deleteCharge()
        }
      }

      fixedChargeDrawer.open({
        title: translate('text_1772133285141kidk35mbh3o'),
        form: { id: FIXED_CHARGE_FORM_ID, submit: form.handleSubmit },
        closeOnSubmitSuccess: false,
        shouldPromptOnClose: () => form.state.isDirty,
        onClose: () => form.reset(),
        onEntered: (container) => {
          if (shouldFocusComboBoxRef.current) {
            shouldFocusComboBoxRef.current = false
            container
              .querySelector<HTMLElement>(
                `.${SEARCH_ADD_ON_IN_FIXED_CHARGE_DRAWER_INPUT_CLASSNAME} .${MUI_INPUT_BASE_ROOT_CLASSNAME}`,
              )
              ?.click()

            return
          }

          focusFirstInput(container)
        },
        children: (
          <PlanFormProvider currency={currency} interval={interval}>
            <FixedChargeDrawerContent
              form={form}
              isCreateMode={isCreateModeRef.current}
              isEdition={isEdition || false}
              isInSubscriptionForm={isInSubscriptionForm || false}
              disabled={disabled || false}
              alertMessage={alertMessageRef.current}
              showCode={showCode}
              existingChargeCodes={existingChargeCodes}
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
            <form.SubmitButton dataTest="fixed-charge-drawer-save">
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
          isUsedInSubscriptionRef.current = options?.isUsedInSubscription || false
          form.reset(
            {
              addOnId: charge.addOn.id,
              addOn: charge.addOn,
              applyUnitsImmediately: charge.applyUnitsImmediately || false,
              chargeModel: charge.chargeModel,
              code: charge.code || '',
              id: charge.id,
              invoiceDisplayName: charge.invoiceDisplayName || '',
              payInAdvance: charge.payInAdvance || false,
              properties: charge.properties || getPropertyShape({}),
              prorated: charge.prorated || false,
              taxes: charge.taxes || [],
              units: charge.units || '',
            },
            { keepDefaultValues: true },
          )
        } else {
          // Create mode
          isCreateModeRef.current = true
          editIndexRef.current = -1
          alertMessageRef.current = undefined
          isUsedInSubscriptionRef.current = false
          form.reset(DEFAULT_VALUES, { keepDefaultValues: true })
          shouldFocusComboBoxRef.current = true
        }

        openFixedChargeDrawer()
      },
      closeDrawer: () => {
        fixedChargeDrawer.close()
      },
    }))

    return null
  },
)

FixedChargeDrawer.displayName = 'FixedChargeDrawer'
