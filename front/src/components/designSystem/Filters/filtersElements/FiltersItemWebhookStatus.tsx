import { useFilterContext } from '~/components/designSystem/Filters/context'
import { MultipleComboBox } from '~/components/form'
import { WebhookStatusEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { formatMultiFilterValue, parseMultiFilterValue } from './utils'

import { FiltersFormValues } from '../types'

type FiltersItemWebhookStatusProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemWebhookStatus = ({
  value,
  setFilterValue,
}: FiltersItemWebhookStatusProps) => {
  const { translate } = useInternationalization()
  const { displayInDialog } = useFilterContext()

  return (
    <MultipleComboBox
      PopperProps={{
        displayInDialog,
      }}
      disableClearable
      disableCloseOnSelect
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={[
        {
          label: translate('text_62da6db136909f52c2704c30'),
          value: WebhookStatusEnum.Pending,
        },
        {
          label: translate('text_1746621029319goh9pr7g67d'),
          value: WebhookStatusEnum.Succeeded,
        },
        {
          label: translate('text_637656ef3d876b0269edc7a1'),
          value: WebhookStatusEnum.Failed,
        },
        {
          label: translate('text_1772097794980io9uophxmwm'),
          value: WebhookStatusEnum.Retrying,
        },
      ]}
      onChange={(statuses) => setFilterValue(formatMultiFilterValue(statuses))}
      value={parseMultiFilterValue(value)}
    />
  )
}
