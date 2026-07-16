import Popper, { type PopperProps } from '@mui/material/Popper'
import { ReactNode } from 'react'

import { theme } from '~/styles'

import { ComboBoxProps } from './types'

type ComboBoxPopperFactoryArgs = Required<Pick<ComboBoxProps, 'PopperProps'>>['PopperProps']

// return a configured <Popper> component with custom styles
export const ComboBoxPopperFactory =
  ({ placement, displayInDialog }: ComboBoxPopperFactoryArgs = {}) =>
  // eslint-disable-next-line react/display-name
  (props: PopperProps) => (
    <Popper
      className="min-w-0"
      sx={{
        zIndex: displayInDialog
          ? `${theme.zIndex.dialog + 1} !important`
          : `${theme.zIndex.popper} !important`,
      }}
      placement={placement || 'bottom-start'}
      modifiers={[
        {
          name: 'offset',
          enabled: true,
          options: {
            offset: [0, 8],
          },
        },
      ]}
      {...props}
    >
      <>{props?.children as ReactNode}</>
    </Popper>
  )
