import { FC } from 'react'

import { ComboBox, TextInput } from '~/components/form'
import { PrivilegeValueTypeEnum } from '~/generated/graphql'
import { TranslateFunc } from '~/hooks/core/useInternationalization'

export const PrivilegeValueInputComponent: FC<{
  valueType: PrivilegeValueTypeEnum
  value: string | undefined
  onChange: (value: string | undefined) => void
  translate: TranslateFunc
  config?: {
    selectOptions?: string[] | null
  }
}> = ({ valueType, value, onChange, translate, config }) => {
  if (valueType === PrivilegeValueTypeEnum.Select) {
    return (
      <ComboBox
        variant="outlined"
        value={value}
        placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
        data={
          config?.selectOptions?.map((option) => ({
            label: option,
            value: option,
          })) || []
        }
        onChange={(newValue) => {
          onChange(newValue)
        }}
      />
    )
  }

  if (valueType === PrivilegeValueTypeEnum.Boolean) {
    return (
      <ComboBox
        variant="outlined"
        value={value}
        placeholder={translate('text_1753864223060ji5l38phiya')}
        data={[
          {
            label: translate('text_65251f46339c650084ce0d57'),
            value: 'true',
          },
          {
            label: translate('text_65251f4cd55aeb004e5aa5ef'),
            value: 'false',
          },
        ]}
        onChange={(newValue) => {
          onChange(newValue)
        }}
      />
    )
  }

  return (
    <TextInput
      variant="outlined"
      value={value}
      placeholder={
        valueType === PrivilegeValueTypeEnum.Integer
          ? translate('text_1753864223060bxskzw3877s')
          : translate('text_1753864223060d5jej59ti86')
      }
      beforeChangeFormatter={
        valueType === PrivilegeValueTypeEnum.Integer ? ['int', 'positiveNumber'] : undefined
      }
      onChange={(newValue) => {
        onChange(String(newValue))
      }}
    />
  )
}
