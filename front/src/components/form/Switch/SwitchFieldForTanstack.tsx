import { useFieldContext } from '~/hooks/forms/formContext'

import { Switch, SwitchProps } from './Switch'

const SwitchField = (
  props: Omit<SwitchProps, 'name' | 'checked' | 'onChange'> & { dataTest?: string },
) => {
  const { dataTest, ...restProps } = props
  const field = useFieldContext<boolean>()

  return (
    <Switch
      {...restProps}
      name={field.name}
      checked={field.state.value}
      onChange={(value) => field.handleChange(value)}
      data-test={dataTest}
    />
  )
}

export default SwitchField
