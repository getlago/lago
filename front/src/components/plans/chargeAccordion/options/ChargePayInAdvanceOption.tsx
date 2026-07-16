import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withFieldGroup } from '~/hooks/forms/useAppform'

type ChargePayInAdvanceOptionValues = {
  payInAdvance: boolean
}

type ChargePayInAdvanceOptionProps = {
  disabled?: boolean
  isPayInAdvanceOptionDisabled?: boolean
  description?: string
  onPayInAdvanceChange?: (payInAdvance: boolean) => void
}

const defaultValues: ChargePayInAdvanceOptionValues = {
  payInAdvance: false,
}

const defaultProps: ChargePayInAdvanceOptionProps = {
  disabled: false,
  isPayInAdvanceOptionDisabled: false,
}

export const ChargePayInAdvanceOption = withFieldGroup({
  defaultValues,
  props: defaultProps,
  render: function Render({
    group,
    disabled,
    isPayInAdvanceOptionDisabled,
    description,
    onPayInAdvanceChange,
  }) {
    const { translate } = useInternationalization()

    return (
      <group.AppField
        name="payInAdvance"
        listeners={{
          onChange: ({ value }) => onPayInAdvanceChange?.(value),
        }}
      >
        {(field) => (
          <field.RadioGroupField
            label={translate('text_6682c52081acea90520743a8')}
            description={description ?? translate('text_1781703119230q5zam349txb')}
            optionLabelVariant="body"
            disabled={disabled}
            options={[
              {
                label: translate('text_6682c52081acea90520743ac'),
                value: false,
              },
              {
                label: translate('text_6682c52081acea90520743ae'),
                value: true,
                disabled: isPayInAdvanceOptionDisabled,
              },
            ]}
          />
        )}
      </group.AppField>
    )
  },
})
