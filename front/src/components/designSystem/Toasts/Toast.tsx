import { cva } from 'class-variance-authority'
import { forwardRef, useCallback, useEffect, useImperativeHandle, useRef, useState } from 'react'

import { removeToast, ToastSeverityEnum, TToast } from '~/core/apolloClient'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { tw } from '~/styles/utils'

import { Button } from '../Button'
import { Typography } from '../Typography'

interface ToastProps {
  toast: TToast
}

interface ToastRef {
  closeToast: () => unknown
}

const AUTO_DISMISS_TIME = 6000

const containerStyles = cva(
  'pointer-events-auto mt-4 box-border flex max-h-[300px] w-fit max-w-[360px] animate-enter items-center justify-start overflow-hidden rounded-xl px-4 py-3 text-white transition-all delay-[0ms] duration-250 ease-in-out',
  {
    variants: {
      severity: {
        info: 'bg-grey-700',
        success: 'bg-green-600',
        danger: 'bg-red-600',
      },
    },
  },
)

export const Toast = forwardRef<ToastRef, ToastProps>(({ toast }: ToastProps, ref) => {
  const [closing, setClosing] = useState(false)
  const timeoutRef = useRef<NodeJS.Timeout | null>(null)
  const { translate } = useInternationalization()
  const { id, severity = ToastSeverityEnum.info, autoDismiss = true, message, translateKey } = toast

  const startTimeout = useCallback(
    (time = AUTO_DISMISS_TIME) => {
      if (!autoDismiss) return

      timeoutRef.current = setTimeout(() => {
        setClosing(true)
      }, time)
    },
    [setClosing, autoDismiss],
  )

  const stopTimeout = useCallback(
    () => autoDismiss && !!timeoutRef.current && clearTimeout(timeoutRef.current || undefined),
    [autoDismiss],
  )

  useEffect(() => {
    startTimeout()

    return () => {
      stopTimeout()
    }
  }, [startTimeout, stopTimeout])

  // Allow parent to ask for toast closing
  useImperativeHandle(ref, () => ({
    closeToast: () => {
      setClosing(true)
    },
  }))

  // Toast should not be closed on hover, so we use onMouseEnter + onMouseLeave
  return (
    <div
      key={id}
      className={tw(containerStyles({ severity }), {
        'mt-0 max-h-0 -translate-x-[120%]': closing,
      })}
      onTransitionEnd={(e) => {
        if (e.propertyName === 'transform' && closing) {
          // Remove toast after transition
          removeToast(id)
        }
      }}
      onMouseEnter={stopTimeout}
      onMouseLeave={() => startTimeout(AUTO_DISMISS_TIME / 2)}
      data-test={`toast/${severity}`}
    >
      <Typography
        className="mr-4 flex-1 [&>a]:text-white [&>a]:underline"
        color="inherit"
        html={translateKey ? translate(translateKey) : message}
      />
      <Button
        onClick={() => setClosing(true)}
        variant="quaternary-light"
        inheritColor
        icon="close"
      />
    </div>
  )
})

Toast.displayName = 'Toast'
