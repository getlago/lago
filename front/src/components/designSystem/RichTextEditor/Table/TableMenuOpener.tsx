import { Icon } from 'lago-design-system'
import { forwardRef } from 'react'

export const TABLE_CONTROLS_ROW_MENU_BUTTON_TEST_ID = 'table-controls-row-menu-button'
export const TABLE_CONTROLS_COL_MENU_BUTTON_TEST_ID = 'table-controls-col-menu-button'

type TableMenuOpenerProps = {
  variant: 'row' | 'col'
  isSelected: boolean
  index: number
  onSelect: () => void
  onClick?: () => void
}

const TableMenuOpener = forwardRef<HTMLButtonElement, TableMenuOpenerProps>(
  function TableMenuOpenerRender({ variant, isSelected, index, onSelect, onClick }, ref) {
    return (
      <button
        ref={ref}
        type="button"
        className={`table-controls__menu-btn table-controls__menu-btn--${variant} ${isSelected ? 'is-selected' : ''}`}
        data-test={`${variant === 'row' ? TABLE_CONTROLS_ROW_MENU_BUTTON_TEST_ID : TABLE_CONTROLS_COL_MENU_BUTTON_TEST_ID}-${index}`}
        aria-label={variant === 'row' ? 'Row options' : 'Column options'}
        onClick={() => {
          onSelect()
          onClick?.()
        }}
      >
        <Icon
          name={variant === 'row' ? 'double-dots-vertical' : 'double-dots-horizontal'}
          size="small"
        />
      </button>
    )
  },
)

export default TableMenuOpener
