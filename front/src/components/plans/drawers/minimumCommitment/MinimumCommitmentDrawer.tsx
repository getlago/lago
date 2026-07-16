import InputAdornment from '@mui/material/InputAdornment'
import { revalidateLogic } from '@tanstack/react-form'
import { forwardRef, useImperativeHandle, useRef } from 'react'
import { z } from 'zod'

import { Button } from '~/components/designSystem/Button'
import { useFormDrawer } from '~/components/drawers/useDrawer'
import { focusFirstInput } from '~/components/drawers/useFocusTrap'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { PlanBillingPeriodInfoSection } from '~/components/plans/drawers/common/PlanBillingPeriodInfoSection'
import { TaxesSelectorSection } from '~/components/taxes/TaxesSelectorSection'
import { PlanFormProvider, usePlanFormContext } from '~/contexts/PlanFormContext'
import { SEARCH_TAX_INPUT_FOR_MIN_COMMITMENT_CLASSNAME } from '~/core/constants/form'
import { getCurrencySymbol } from '~/core/formats/intlFormatNumber'
import { CurrencyEnum, TaxForPlanAndChargesInPlanFormFragment } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

const MINIMUM_COMMITMENT_DRAWER_SAVE_TEST_ID = 'minimum-commitment-drawer-save'

const MINIMUM_COMMITMENT_FORM_ID = 'minimum-commitment-drawer-form'

export interface MinimumCommitmentFormValues {
  amountCents: string
  invoiceDisplayName?: string
  taxes: TaxForPlanAndChargesInPlanFormFragment[]
}

const minimumCommitmentSchema = z.object({
  amountCents: z
    .string()
    .min(1, 'text_1771342994699klxu2paz7g8')
    .refine((val) => Number(val) > 0, 'text_632d68358f1fedc68eed3e91'),
  invoiceDisplayName: z.string().optional(),
  taxes: z.array(z.custom<TaxForPlanAndChargesInPlanFormFragment>()),
})

const DEFAULT_VALUES: MinimumCommitmentFormValues = {
  amountCents: '',
  invoiceDisplayName: undefined,
  taxes: [],
}

export interface MinimumCommitmentDrawerRef {
  openDrawer: (values?: MinimumCommitmentFormValues) => void
  closeDrawer: () => void
}

interface MinimumCommitmentDrawerProps {
  onSave: (values: MinimumCommitmentFormValues) => void | boolean | Promise<void | boolean>
  onDelete?: () => void
}

export const MinimumCommitmentDrawer = forwardRef<
  MinimumCommitmentDrawerRef,
  MinimumCommitmentDrawerProps
>(({ onSave, onDelete }, ref) => {
  const { translate } = useInternationalization()
  const { currency, interval } = usePlanFormContext()
  const minimumCommitmentDrawer = useFormDrawer()
  const isAddModeRef = useRef(false)

  const form = useAppForm({
    defaultValues: DEFAULT_VALUES,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: minimumCommitmentSchema,
    },
    onSubmit: async ({ value }) => {
      const result = await onSave({
        ...value,
        invoiceDisplayName: value.invoiceDisplayName || undefined,
      })

      if (result !== false) {
        minimumCommitmentDrawer.close()
      }
    },
  })

  const openMinimumCommitmentDrawer = () => {
    const showDelete = !isAddModeRef.current && !!onDelete

    const handleDelete = () => {
      minimumCommitmentDrawer.close()
      onDelete?.()
    }

    minimumCommitmentDrawer.open({
      title: translate('text_65d601bffb11e0f9d1d9f569'),
      form: { id: MINIMUM_COMMITMENT_FORM_ID, submit: form.handleSubmit },
      closeOnSubmitSuccess: false,
      shouldPromptOnClose: () => form.state.isDirty,
      onClose: () => form.reset(),
      onEntered: focusFirstInput,
      children: (
        <PlanFormProvider currency={currency} interval={interval}>
          <CenteredPage.SectionWrapper>
            <CenteredPage.PageTitle
              title={translate('text_65d601bffb11e0f9d1d9f569')}
              description={translate('text_177334593394555w48sxw5na')}
            />

            <CenteredPage.SubsectionWrapper>
              <CenteredPage.PageSection>
                <CenteredPage.PageSectionTitle title={translate('text_1773346168045bj2x1626228')} />

                <PlanBillingPeriodInfoSection />

                <form.AppField name="amountCents">
                  {(field) => (
                    <field.AmountInputField
                      currency={currency}
                      beforeChangeFormatter={['positiveNumber']}
                      label={translate('text_65d601bffb11e0f9d1d9f571')}
                      InputProps={{
                        startAdornment: (
                          <InputAdornment position="start">
                            {getCurrencySymbol(currency || CurrencyEnum.Usd)}
                          </InputAdornment>
                        ),
                      }}
                    />
                  )}
                </form.AppField>
              </CenteredPage.PageSection>

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

                <form.Subscribe selector={(state) => state.values.taxes}>
                  {(taxes) => (
                    <TaxesSelectorSection
                      title={translate('text_1760729707267seik64l67k8')}
                      description={translate('text_1773346168045bj2x1626229')}
                      taxes={taxes || []}
                      comboboxSelector={SEARCH_TAX_INPUT_FOR_MIN_COMMITMENT_CLASSNAME}
                      onUpdate={(newTaxArray) => {
                        form.setFieldValue('taxes', newTaxArray)
                      }}
                    />
                  )}
                </form.Subscribe>
              </CenteredPage.PageSection>
            </CenteredPage.SubsectionWrapper>
          </CenteredPage.SectionWrapper>
        </PlanFormProvider>
      ),
      secondaryAction: showDelete ? (
        <Button danger variant="quaternary" onClick={handleDelete}>
          {translate('text_63ea0f84f400488553caa786')}
        </Button>
      ) : undefined,
      mainAction: (
        <form.AppForm>
          <form.SubmitButton dataTest={MINIMUM_COMMITMENT_DRAWER_SAVE_TEST_ID}>
            {translate(
              isAddModeRef.current
                ? 'text_1775225915210r5vkxkn0mvx'
                : 'text_17295436903260tlyb1gp1i7',
            )}
          </form.SubmitButton>
        </form.AppForm>
      ),
    })
  }

  useImperativeHandle(ref, () => ({
    openDrawer: (values?: MinimumCommitmentFormValues) => {
      isAddModeRef.current = !values
      if (values) {
        form.reset(
          {
            ...values,
            taxes: values.taxes ?? [],
          },
          { keepDefaultValues: true },
        )
      } else {
        form.reset(DEFAULT_VALUES, { keepDefaultValues: true })
      }

      openMinimumCommitmentDrawer()
    },
    closeDrawer: () => {
      minimumCommitmentDrawer.close()
    },
  }))

  return null
})

MinimumCommitmentDrawer.displayName = 'MinimumCommitmentDrawer'
