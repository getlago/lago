import { useStore } from '@tanstack/react-form'

import { ChargeTable } from '~/components/designSystem/Table/ChargeTable'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { ComboBox } from '~/components/form'
import { TextInput } from '~/components/form/TextInput/TextInput'
import { LocalPrivilegeInput } from '~/components/plans/types'
import { PrivilegeValueTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useFieldContext } from '~/hooks/forms/formContext'
import { withForm } from '~/hooks/forms/useAppform'

import { DEFAULT_VALUES } from './constants'

export const PrivilegesTable = withForm({
  defaultValues: DEFAULT_VALUES,
  props: {
    featureCode: '',
  },
  render: function Render({ form, featureCode }) {
    const { translate } = useInternationalization()
    const privileges = useStore(form.store, (state) => state.values.privileges)

    return (
      <div className="-mx-4 -my-1 w-full overflow-auto px-4 py-1">
        <ChargeTable
          className="w-full"
          name={`feature-entitlement-${featureCode}-privilege-table`}
          data={privileges}
          deleteTooltipContent={translate('text_17538642230608t3xmlgja96')}
          onDeleteRow={(_row, index) => {
            form.removeFieldValue('privileges', index)
          }}
          columns={[
            {
              size: 290,
              title: (
                <Typography variant="captionHl" className="px-4">
                  {translate('text_175386422306019wldpp8h5q')}
                </Typography>
              ),
              content: (row) => (
                <Typography variant="body" color="grey700" className="px-4">
                  {row.privilegeName || row.privilegeCode}
                </Typography>
              ),
            },
            {
              size: 310,
              title: (
                <Typography variant="captionHl" className="px-4">
                  {translate('text_63fcc3218d35b9377840f5ab')}
                </Typography>
              ),
              content: (row, rowIndex) => (
                <form.AppField name={`privileges[${rowIndex}].value`}>
                  {() => <PrivilegeValueCell row={row} />}
                </form.AppField>
              ),
            },
          ]}
        />
      </div>
    )
  },
})

function PrivilegeValueCell({ row }: Readonly<{ row: LocalPrivilegeInput }>) {
  const field = useFieldContext<string>()
  const { translate } = useInternationalization()

  const errors = useStore(field.store, (state) => state.meta.errors)
  const hasError = errors.length > 0
  const errorMessage = hasError ? translate(errors.map((e) => e.message).join(' ') as string) : ''

  if (row.valueType === PrivilegeValueTypeEnum.Select) {
    return (
      <Tooltip title={errorMessage} disableHoverListener={!hasError} placement="top">
        <ComboBox
          variant="outlined"
          value={field.state.value}
          error={hasError}
          placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
          data={
            row.config?.selectOptions?.map((option) => ({
              label: option,
              value: option,
            })) || []
          }
          onChange={(v) => field.handleChange(v)}
        />
      </Tooltip>
    )
  }

  if (row.valueType === PrivilegeValueTypeEnum.Boolean) {
    return (
      <Tooltip title={errorMessage} disableHoverListener={!hasError} placement="top">
        <ComboBox
          variant="outlined"
          value={field.state.value}
          error={hasError}
          placeholder={translate('text_1753864223060ji5l38phiya')}
          data={[
            { label: translate('text_65251f46339c650084ce0d57'), value: 'true' },
            { label: translate('text_65251f4cd55aeb004e5aa5ef'), value: 'false' },
          ]}
          onChange={(v) => field.handleChange(v)}
        />
      </Tooltip>
    )
  }

  return (
    <Tooltip title={errorMessage} disableHoverListener={!hasError} placement="top">
      <TextInput
        name={field.name}
        value={field.state.value}
        onChange={(value) => field.handleChange(String(value ?? ''))}
        onBlur={field.handleBlur}
        error={hasError}
        variant="outlined"
        placeholder={
          row.valueType === PrivilegeValueTypeEnum.Integer
            ? translate('text_1753864223060bxskzw3877s')
            : translate('text_1753864223060d5jej59ti86')
        }
        beforeChangeFormatter={
          row.valueType === PrivilegeValueTypeEnum.Integer ? ['int', 'positiveNumber'] : undefined
        }
      />
    </Tooltip>
  )
}
