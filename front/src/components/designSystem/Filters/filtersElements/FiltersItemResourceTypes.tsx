import { useFilters } from '~/components/designSystem/Filters/useFilters'
import { MultipleComboBox } from '~/components/form'
import { ResourceTypeEnum } from '~/generated/graphql'
import { useActivityLogsInformation } from '~/hooks/activityLogs/useActivityLogsInformation'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemResourceTypesProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemResourceTypes = ({
  value,
  setFilterValue,
}: FiltersItemResourceTypesProps) => {
  const { translate } = useInternationalization()
  const { displayInDialog } = useFilters()
  const { getResourceType } = useActivityLogsInformation()

  return (
    <MultipleComboBox
      PopperProps={{
        displayInDialog,
      }}
      disableClearable
      disableCloseOnSelect
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={Object.values(ResourceTypeEnum).map((resourceType) => ({
        label: getResourceType(resourceType),
        value: resourceType,
      }))}
      onChange={(invoiceType) => {
        setFilterValue(String(invoiceType.map((v) => v.value).join(',')))
      }}
      value={value
        ?.split(',')
        .filter((v) => !!v)
        .map((v) => ({ value: v }))}
    />
  )
}
