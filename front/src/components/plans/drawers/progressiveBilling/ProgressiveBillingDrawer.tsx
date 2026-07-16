import { revalidateLogic } from '@tanstack/react-form'
import { tw } from 'lago-design-system'
import { forwardRef, useImperativeHandle, useRef } from 'react'

import { Button } from '~/components/designSystem/Button'
import { useDrawer } from '~/components/drawers/useDrawer'
import { focusFirstInput } from '~/components/drawers/useFocusTrap'
import { PlanFormProvider, usePlanFormContext } from '~/contexts/PlanFormContext'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

import { DEFAULT_VALUES, ProgressiveBillingFormValues, progressiveBillingSchema } from './constants'
import { ProgressiveBillingDrawerContent } from './ProgressiveBillingDrawerContent'

const PROGRESSIVE_BILLING_DRAWER_SAVE_TEST_ID = 'progressive-billing-drawer-save'

export interface ProgressiveBillingDrawerRef {
  openDrawer: (values?: ProgressiveBillingFormValues) => void
  closeDrawer: () => void
}

interface ProgressiveBillingDrawerProps {
  onSave: (values: ProgressiveBillingFormValues) => void | boolean | Promise<void | boolean>
  onDelete?: () => void
}

export const ProgressiveBillingDrawer = forwardRef<
  ProgressiveBillingDrawerRef,
  ProgressiveBillingDrawerProps
>(({ onSave, onDelete }, ref) => {
  const { translate } = useInternationalization()
  const { currency, interval } = usePlanFormContext()
  const progressiveBillingDrawer = useDrawer()
  const isEditModeRef = useRef(false)
  const initialDisplayRecurringRef = useRef(false)

  const form = useAppForm({
    defaultValues: DEFAULT_VALUES,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: progressiveBillingSchema,
    },
    onSubmit: async ({ value }) => {
      const result = await onSave(value)

      if (result !== false) {
        progressiveBillingDrawer.close()
      }
    },
  })

  const handleFormSubmit = () => {
    form.handleSubmit()
  }

  const openProgressiveBillingDrawer = () => {
    const showDelete = isEditModeRef.current && !!onDelete

    const handleDelete = () => {
      progressiveBillingDrawer.close()
      onDelete?.()
    }

    progressiveBillingDrawer.open({
      title: translate('text_1724179887722baucvj7bvc1'),
      shouldPromptOnClose: () => form.state.isDirty,
      onClose: () => form.reset(),
      onEntered: focusFirstInput,
      children: (
        <PlanFormProvider currency={currency} interval={interval}>
          <ProgressiveBillingDrawerContent
            form={form}
            initialDisplayRecurring={!!initialDisplayRecurringRef.current}
          />
        </PlanFormProvider>
      ),
      actions: (
        <div
          className={tw(
            'flex items-center gap-3',
            showDelete ? 'w-full justify-between' : 'justify-end',
          )}
        >
          {showDelete && (
            <Button danger variant="quaternary" onClick={handleDelete}>
              {translate('text_63ea0f84f400488553caa786')}
            </Button>
          )}
          <div className="flex items-center gap-3">
            <Button variant="quaternary" onClick={() => progressiveBillingDrawer.close()}>
              {translate('text_6411e6b530cb47007488b027')}
            </Button>
            <form.Subscribe selector={({ canSubmit }) => canSubmit}>
              {(canSubmit) => (
                <Button
                  data-test={PROGRESSIVE_BILLING_DRAWER_SAVE_TEST_ID}
                  onClick={handleFormSubmit}
                  disabled={!canSubmit}
                >
                  {translate(
                    isEditModeRef.current
                      ? 'text_17295436903260tlyb1gp1i7'
                      : 'text_1775225915210s2oemt3bl21',
                  )}
                </Button>
              )}
            </form.Subscribe>
          </div>
        </div>
      ),
    })
  }

  useImperativeHandle(ref, () => ({
    openDrawer: (values?: ProgressiveBillingFormValues) => {
      const resetValues = values ?? DEFAULT_VALUES

      isEditModeRef.current = !!values
      initialDisplayRecurringRef.current = !!resetValues.recurringUsageThreshold

      form.reset(resetValues, { keepDefaultValues: true })

      openProgressiveBillingDrawer()
    },
    closeDrawer: () => {
      progressiveBillingDrawer.close()
    },
  }))

  return null
})

ProgressiveBillingDrawer.displayName = 'ProgressiveBillingDrawer'
