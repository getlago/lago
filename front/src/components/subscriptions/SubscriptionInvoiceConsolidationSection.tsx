import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withFieldGroup } from '~/hooks/forms/useAppform'

export const CONSOLIDATION_SECTION_TEST_ID = 'consolidation-section'

type SubscriptionInvoiceConsolidationGroupValues = {
  consolidateInvoice: boolean
}

const defaultValues: SubscriptionInvoiceConsolidationGroupValues = {
  consolidateInvoice: true,
}

export const SubscriptionInvoiceConsolidationSection = withFieldGroup({
  defaultValues,
  render: function Render({ group }) {
    const { translate } = useInternationalization()

    return (
      <div data-test={CONSOLIDATION_SECTION_TEST_ID}>
        <group.AppField name="consolidateInvoice">
          {(field) => (
            <field.RadioGroupField
              optionsGapSpacing={3}
              optionLabelVariant="body"
              options={[
                {
                  value: true,
                  label: translate('text_1778745351091h7z5baw0ta6'),
                  sublabel: translate('text_1778745351091u1rjnmr88ua'),
                },
                {
                  value: false,
                  label: translate('text_1778745351091fxaqr5dwok8'),
                  sublabel: translate('text_177874535109218palud3t3o'),
                },
              ]}
            />
          )}
        </group.AppField>
      </div>
    )
  },
})
