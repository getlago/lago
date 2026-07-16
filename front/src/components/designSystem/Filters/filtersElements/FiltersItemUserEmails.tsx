import { TextInput } from '~/components/form'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemUserEmailsProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemUserEmails = ({ value, setFilterValue }: FiltersItemUserEmailsProps) => {
  const { translate } = useInternationalization()

  return (
    <TextInput
      placeholder={translate('text_1741014096283pwl7a5oa69a')}
      value={value}
      onChange={(val) => setFilterValue(val)}
    />
  )
}
