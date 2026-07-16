/* eslint-disable @typescript-eslint/no-explicit-any */
import { Icon, IconName } from 'lago-design-system'
import { forwardRef, MouseEvent, ReactNode, useEffect, useRef, useState } from 'react'

import { Typography } from '~/components/designSystem/Typography'
import { tw } from '~/styles/utils'

export interface TabButtonProps {
  active?: boolean
  title?: string | number | boolean
  disabled?: boolean
  icon?: IconName | ReactNode
  className?: string
  onClick?: (e: MouseEvent<HTMLButtonElement>) => unknown
}

export const TabButton = forwardRef<HTMLButtonElement, TabButtonProps>(
  (
    { active = false, title, icon, className, disabled, onClick, ...props }: TabButtonProps,
    ref,
  ) => {
    const [isLoading, setIsLoading] = useState(false)
    const mountedRef = useRef(false)

    useEffect(() => {
      // This is for preventing setstate on unmounted component
      mountedRef.current = true

      return () => {
        mountedRef.current = false
      }
    }, [])

    return (
      <button
        {...props}
        type="button"
        ref={ref}
        className={tw(
          'transition-250 flex min-h-10 items-center justify-center rounded-xl px-3 py-[6px] font-sans outline-none transition-colors ease-in',
          active
            ? 'bg-grey-200 text-blue'
            : 'bg-white text-grey-500 shadow-[0px_0px_0px_1px_#8C95A6_inset] focus-not-active:rounded-xl focus-not-active:shadow-none focus-not-active:ring hover-not-active:bg-grey-200',
          'disabled:bg-transparent disabled:pointer-events-none disabled:cursor-default disabled:text-grey-400 disabled:shadow-none',
          active ? 'disabled:bg-grey-100' : 'disabled:bg-transparent',
          'not-last-child:mr-2',
          className,
        )}
        disabled={disabled}
        tabIndex={disabled || active ? -1 : 0}
        onClick={(e) => {
          e.preventDefault()

          if (onClick) {
            const res = onClick(e)

            if (res !== null && (res as any) instanceof Promise) {
              let realLoading = true

              // This is to prenvent icon blink if the loading time is really small
              setTimeout(() => {
                if (mountedRef.current && realLoading) setIsLoading(true)
              }, 100)
              ;(res as unknown as Promise<any>).finally(() => {
                if (mountedRef.current) {
                  realLoading = false
                  setIsLoading(false)
                }
              })
            }
          }
        }}
      >
        {isLoading && <Icon name="processing" animation="spin" />}
        {!isLoading && typeof icon === 'string' && <Icon name={icon as IconName} />}
        {!isLoading && typeof icon !== 'string' && !!icon && icon}
        {title && (
          <Typography className="flex-1" noWrap color="inherit">
            {title}
          </Typography>
        )}
      </button>
    )
  },
)

TabButton.displayName = 'TabButton'
