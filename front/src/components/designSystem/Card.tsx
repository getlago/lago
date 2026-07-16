import { FC, PropsWithChildren } from 'react'

import { tw } from '~/styles/utils'

export interface CardProps {
  className?: string
}

export const Card: FC<PropsWithChildren<CardProps>> = ({ children, className }) => {
  return (
    <div
      className={tw(
        'flex flex-col gap-6 rounded-xl border border-grey-300 bg-white p-8',
        className,
      )}
    >
      {children}
    </div>
  )
}
