import { PropsWithChildren } from 'react'

import { tw } from '~/styles/utils'

export const ChartWrapper = ({
  children,
  className,
  blur,
}: PropsWithChildren & { className?: string; blur?: boolean }) => (
  <div
    className={tw(className, {
      'pointer-events-none blur-sm': blur,
    })}
  >
    {children}
  </div>
)
