import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withFieldGroup } from '~/hooks/forms/useAppform'

import { EXISTING_CODE_ERROR_MESSAGE } from './chargeCode'

type ChargeCodeFieldValues = {
  code: string
}

type ChargeCodeFieldProps = {
  disabled?: boolean
}

const defaultValues: ChargeCodeFieldValues = {
  code: '',
}

const defaultProps: ChargeCodeFieldProps = {
  disabled: false,
}

// Editable unique charge code, shared by the fixed- and usage-charge drawers.
// Mounted via `<ChargeCodeField form={form} fields={{ code: 'code' }} />`.
const ChargeCodeField = withFieldGroup({
  defaultValues,
  props: defaultProps,
  render: function Render({ group, disabled }) {
    const { translate } = useInternationalization()

    return (
      <group.AppField
        name="code"
        listeners={{
          // Clear the server "code already exists" error once the user edits the
          // code so the submit button re-enables. Gated by the message so the zod
          // required-check isn't wiped.
          onChange: () => {
            const meta = group.getFieldMeta('code')

            if (meta?.errorMap?.onDynamic?.message === EXISTING_CODE_ERROR_MESSAGE) {
              group.setFieldMeta('code', (current) => ({
                ...current,
                errorMap: { ...current.errorMap, onDynamic: undefined },
              }))
            }
          },
        }}
      >
        {(field) => (
          <field.TextInputField
            label={translate('text_629728388c4d2300e2d380b7')}
            placeholder={translate('text_629728388c4d2300e2d380d9')}
            beforeChangeFormatter="code"
            disabled={disabled}
          />
        )}
      </group.AppField>
    )
  },
})

export default ChargeCodeField
