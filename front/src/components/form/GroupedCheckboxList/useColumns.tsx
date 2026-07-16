import { Icon } from 'lago-design-system'
import { ComponentType, ReactNode } from 'react'

import { ColumnConfig, ColumnHelpers } from '~/components/designSystem/Table/TableWithGroups'
import { Typography, TypographyProps } from '~/components/designSystem/Typography'
import { Checkbox } from '~/components/form'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { CheckboxFieldApi, GroupingMap, RowConfigWithSublabel } from './types'
import { countEnabledItemsInGroup, getGroupCheckboxValue } from './utils'

type UseColumnsParams<TValues extends Record<string, boolean>> = {
  isEditable: boolean
  checkboxValues: TValues
  groupingMap: GroupingMap
  overallCheckboxValue: boolean | undefined
  onOverallCheckboxChange: (_e: unknown, checked: boolean) => void
  onGroupCheckboxClick: (checked: boolean, groupItems: Array<{ id: string; label: string }>) => void
  itemLabelVariant?: TypographyProps['variant']
  AppField: ComponentType<{
    name: keyof TValues & string
    key?: string
    children: (field: CheckboxFieldApi) => ReactNode
  }>
}

export const useColumns = <TValues extends Record<string, boolean>>({
  isEditable,
  checkboxValues,
  groupingMap,
  overallCheckboxValue,
  onOverallCheckboxChange,
  onGroupCheckboxClick,
  itemLabelVariant,
  AppField,
}: UseColumnsParams<TValues>): ColumnConfig[] => {
  const { translate } = useInternationalization()

  const createIcon = (itemId: string) => {
    const isChecked = checkboxValues[itemId as keyof TValues]

    if (isChecked) {
      return <Icon name="validate-filled" size="medium" color="success" />
    }

    return <Icon name="close-circle-filled" size="medium" color="input" />
  }

  const LabelColumnContent = (
    row: RowConfigWithSublabel,
    { ChevronIcon }: ColumnHelpers,
  ): ReactNode => {
    const isGroup = row.type === 'group'

    return (
      <div className="flex flex-row items-center gap-2">
        {ChevronIcon}
        {typeof row.label !== 'string' && row.label}
        {typeof row.label === 'string' && isGroup && (
          <Typography variant="bodyHl" color="grey700" noWrap>
            {row.label}
          </Typography>
        )}
        {typeof row.label === 'string' && !isGroup && (
          <div className="flex flex-col py-3 pl-8">
            <div className="flex flex-row items-center gap-2">
              {!isEditable && createIcon(row.key)}
              <Typography variant={itemLabelVariant} color="grey700" noWrap>
                {row.label}
              </Typography>
            </div>
            {row.sublabel && (
              <Typography
                variant="caption"
                color="grey600"
                sx={{
                  lineHeight: 1.3,
                }}
              >
                {row.sublabel}
              </Typography>
            )}
          </div>
        )}
      </div>
    )
  }

  const getCheckboxColumn = (): ColumnConfig[] => {
    if (!isEditable) {
      return []
    }

    return [
      {
        key: 'checkbox',
        label: (
          <Checkbox
            label={null}
            value={overallCheckboxValue}
            canBeIndeterminate
            onChange={onOverallCheckboxChange}
          />
        ),
        minWidth: 40,
        content: (row) => {
          if (row.type === 'group') {
            const checkboxValue = getGroupCheckboxValue(row.key, groupingMap, checkboxValues)

            return (
              <Checkbox
                value={checkboxValue}
                canBeIndeterminate
                disabled={!isEditable}
                onChange={(_e, checked) =>
                  onGroupCheckboxClick(checked, groupingMap[row.key].items)
                }
                label={null}
              />
            )
          }

          const fieldName = row.key as keyof TValues & string

          return (
            <AppField name={fieldName}>
              {(field) => <field.CheckboxField label={null} disabled={!isEditable} />}
            </AppField>
          )
        },
      },
    ]
  }

  const columns: ColumnConfig[] = [
    ...getCheckboxColumn(),
    {
      key: 'label',
      label: translate('text_1766047828726zeybs9mgzhl'),
      minWidth: 230,
      content: LabelColumnContent,
      isFullWidth: true,
    },
    {
      key: 'total',
      label: translate('text_1766047828725ykfgqmtfczr'),
      align: 'right',
      minWidth: 120,
      content: (row) => {
        if (row.type === 'group') {
          const { enabled, total } = countEnabledItemsInGroup(row.key, groupingMap, checkboxValues)

          return (
            <Typography color="grey500">
              {enabled} / {total}
            </Typography>
          )
        }

        return null
      },
    },
  ]

  return columns
}
