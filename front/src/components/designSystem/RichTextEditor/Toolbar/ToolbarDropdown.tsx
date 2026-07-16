import { Icon } from 'lago-design-system'
import { ReactElement } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { Typography } from '~/components/designSystem/Typography'
import { MenuPopper } from '~/styles/designSystem/PopperComponents'

import { DropdownItem } from './types'

const ToolbarDropdown = ({
  items,
  opener,
  'data-test': dataTest,
}: {
  items: DropdownItem[]
  opener: ReactElement
  'data-test'?: string
}) => (
  <Popper PopperProps={{ placement: 'bottom-start' }} opener={opener}>
    {({ closePopper }) => (
      <MenuPopper>
        {items.map((item) => (
          <Button
            key={item.value}
            data-test={dataTest ? `${dataTest}-${item.value}` : undefined}
            variant="quaternary"
            align="left"
            onClick={() => {
              item.onButtonClick()
              closePopper()
            }}
          >
            <div className="flex items-center gap-2">
              {item.label && <Typography>{item.label}</Typography>}
              <Typography color="grey700">{item.name}</Typography>
              {item.isActive && <Icon name="checkmark" />}
            </div>
          </Button>
        ))}
      </MenuPopper>
    )}
  </Popper>
)

export default ToolbarDropdown
