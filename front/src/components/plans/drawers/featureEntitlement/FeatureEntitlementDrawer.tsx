import { revalidateLogic } from '@tanstack/react-form'
import { tw } from 'lago-design-system'
import { forwardRef, useImperativeHandle, useRef } from 'react'
import { z } from 'zod'

import { Button } from '~/components/designSystem/Button'
import { useDrawer } from '~/components/drawers/useDrawer'
import {
  MUI_INPUT_BASE_ROOT_CLASSNAME,
  SEARCH_FEATURE_SELECT_OPTIONS_INPUT_CLASSNAME,
} from '~/core/constants/form'
import { scrollToAndClickElement } from '~/core/utils/domUtils'
import { PrivilegeValueTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

import { DEFAULT_VALUES, type FeatureEntitlementFormValues } from './constants'
import { FeatureEntitlementDrawerContent } from './FeatureEntitlementDrawerContent'

export { type FeatureEntitlementFormValues } from './constants'

const privilegeSchema = z.object({
  privilegeCode: z.string().min(1),
  privilegeName: z.string().nullable(),
  value: z.string().min(1, 'text_1771342994699klxu2paz7g8'),
  id: z.string().optional(),
  valueType: z.custom<PrivilegeValueTypeEnum>(),
  config: z.object({ selectOptions: z.array(z.string()).nullable().optional() }).optional(),
})

const featureEntitlementSchema = z.object({
  featureId: z.string(),
  featureName: z.string(),
  featureCode: z.string().min(1, 'text_1771342994699klxu2paz7g8'),
  privileges: z.array(privilegeSchema),
})

export interface FeatureEntitlementDrawerRef {
  openDrawer: (values?: FeatureEntitlementFormValues) => void
  closeDrawer: () => void
}

interface FeatureEntitlementDrawerProps {
  onSave: (values: FeatureEntitlementFormValues) => void | boolean | Promise<void | boolean>
  onDelete?: (featureCode: string) => void
  existingFeatureCodes: string[]
}

export const FeatureEntitlementDrawer = forwardRef<
  FeatureEntitlementDrawerRef,
  FeatureEntitlementDrawerProps
>(({ onSave, onDelete, existingFeatureCodes }, ref) => {
  const { translate } = useInternationalization()
  const entitlementDrawer = useDrawer()
  const isAddModeRef = useRef(true)
  const featureCodeRef = useRef('')

  const form = useAppForm({
    defaultValues: DEFAULT_VALUES,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: featureEntitlementSchema,
    },
    onSubmit: async ({ value }) => {
      const result = await onSave({
        ...value,
        privileges: value.privileges || [],
      })

      if (result !== false) {
        entitlementDrawer.close()
      }
    },
  })

  const handleFormSubmit = () => {
    form.handleSubmit()
  }

  const openEntitlementDrawer = () => {
    const showDelete = !isAddModeRef.current && !!onDelete

    const handleDelete = () => {
      entitlementDrawer.close()
      onDelete?.(featureCodeRef.current)
    }

    entitlementDrawer.open({
      title: translate('text_63e26d8308d03687188221a6'),
      shouldPromptOnClose: () => form.state.isDirty,
      onClose: () => form.reset(),
      onEntered: () => {
        if (isAddModeRef.current) {
          scrollToAndClickElement({
            selector: `.${SEARCH_FEATURE_SELECT_OPTIONS_INPUT_CLASSNAME} .${MUI_INPUT_BASE_ROOT_CLASSNAME}`,
          })
        }
      },
      children: (
        <FeatureEntitlementDrawerContent form={form} existingFeatureCodes={existingFeatureCodes} />
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
            <Button variant="quaternary" onClick={() => entitlementDrawer.close()}>
              {translate('text_6411e6b530cb47007488b027')}
            </Button>
            <form.Subscribe selector={({ canSubmit }) => canSubmit}>
              {(canSubmit) => (
                <Button
                  data-test="feature-entitlement-drawer-save"
                  onClick={handleFormSubmit}
                  disabled={!canSubmit}
                >
                  {translate(
                    isAddModeRef.current
                      ? 'text_1775225915210g1crmnurgor'
                      : 'text_17295436903260tlyb1gp1i7',
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
    openDrawer: (values?: FeatureEntitlementFormValues) => {
      isAddModeRef.current = !values
      featureCodeRef.current = values?.featureCode ?? ''
      if (values) {
        form.reset({ ...values, privileges: values.privileges ?? [] }, { keepDefaultValues: true })
      } else {
        form.reset()
      }

      openEntitlementDrawer()
    },
    closeDrawer: () => {
      entitlementDrawer.close()
    },
  }))

  return null
})

FeatureEntitlementDrawer.displayName = 'FeatureEntitlementDrawer'
