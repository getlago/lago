import { FC, forwardRef, PropsWithChildren } from 'react'

import { tw } from '~/styles/utils'

export const MenuPopper: FC<PropsWithChildren<{ className?: string }>> = ({
  className,
  children,
}) => <div className={tw('flex flex-col gap-1 p-2', className)}>{children}</div>

// Note: we must use forwardRef and props spread because some invocations use them to place the element in the parent
// E.g. in the Table component, the Popper passes those props implicitely to the PopperOpener.
export const PopperOpener = forwardRef<HTMLDivElement, PropsWithChildren<{ className?: string }>>(
  ({ children, className, ...props }, ref) => {
    return (
      <div
        ref={ref}
        className={tw('absolute right-12 top-4 z-10 md:right-4', className)}
        {...props}
      >
        {children}
      </div>
    )
  },
)

PopperOpener.displayName = 'PopperOpener'
