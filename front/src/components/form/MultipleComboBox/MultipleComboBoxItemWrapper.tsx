import { cx } from 'class-variance-authority'
import { Icon } from 'lago-design-system'

import { ConditionalWrapper } from '~/components/ConditionalWrapper'
import { Typography } from '~/components/designSystem/Typography'
import { Link } from '~/core/router'

import { MultipleComboBoxData } from './types'

import { Checkbox } from '../Checkbox'
import { ComboboxItem } from '../ComboBox'

interface MultipleComboBoxItemProps {
  id: string
  option: MultipleComboBoxData
  selected?: boolean
  multipleComboBoxProps: React.HTMLAttributes<HTMLLIElement>
  virtualized?: boolean
  addValueRedirectionUrl?: string
}

export const MultipleComboBoxItemWrapper = ({
  id,
  option: { customValue, value, label, description, disabled, labelNode },
  selected,
  virtualized,
  multipleComboBoxProps,
  addValueRedirectionUrl,
}: MultipleComboBoxItemProps) => {
  const { className, ...allProps } = multipleComboBoxProps

  return (
    <div
      className="remove-child-link-style flex min-h-14 items-center"
      data-test={`multipleComboBox-item-${label}`}
    >
      <ConditionalWrapper
        condition={!!addValueRedirectionUrl}
        invalidWrapper={(children) => <>{children}</>}
        validWrapper={(children) => <Link to={addValueRedirectionUrl as string}>{children}</Link>}
      >
        <ComboboxItem
          id={id}
          virtualized={virtualized}
          className={cx(
            'items-start',
            {
              'cursor-auto': disabled,
            },
            className,
          )}
          data-test={value}
          key={value}
          {...allProps}
        >
          {customValue ? (
            <ComboboxItem className="flex-row !items-center !justify-start">
              <Icon className="mr-4" color="dark" name="plus" />
              <Typography variant="body" noWrap>
                {labelNode ?? label}
              </Typography>
            </ComboboxItem>
          ) : (
            <Checkbox
              disabled={disabled}
              name={value}
              value={!!selected}
              sublabel={description}
              label={labelNode || label || value}
            />
          )}
        </ComboboxItem>
      </ConditionalWrapper>
    </div>
  )
}
