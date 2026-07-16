import { FC, PropsWithChildren } from 'react'

import { tw } from '../utils'

export const DrawerContent: FC<PropsWithChildren<{ className?: string }>> = ({
  children,
  className,
}) => <div className={tw('flex flex-col gap-8', className)}>{children}</div>

export const DrawerTitle: FC<PropsWithChildren> = ({ children }) => (
  <div className="px-8">{children}</div>
)

export const DrawerSubmitButton: FC<PropsWithChildren> = ({ children }) => (
  <div className="mx-8">{children}</div>
)
