import { FC, PropsWithChildren } from 'react'

import { tw } from '~/styles/utils'

export const ComboboxItem: FC<PropsWithChildren<{ virtualized?: boolean; className?: string }>> = ({
  children,
  className,
  virtualized,
  ...props
}) => (
  <div
    className={tw(
      'flex w-full cursor-pointer flex-col !items-start !justify-center rounded-xl',
      className,
    )}
    style={{
      width: !!virtualized ? 'initial' : 'inherit',
    }}
    {...props}
  >
    {children}
  </div>
)
