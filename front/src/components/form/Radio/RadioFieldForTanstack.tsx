import { useFieldContext } from '~/hooks/forms/formContext'

import { Radio, RadioProps } from './Radio'

const RadioField = ({ value, ...props }: Omit<RadioProps, 'name' | 'checked' | 'onChange'>) => {
  const field = useFieldContext<string>()

  return (
    <Radio
      {...props}
      name={field.name}
      value={value}
      checked={field.state.value === value}
      onChange={() => field.handleChange(value as string)}
    />
  )
}

export default RadioField
