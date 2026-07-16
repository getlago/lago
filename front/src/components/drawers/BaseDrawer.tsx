import { ReactNode, useCallback, useEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'

import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { tw } from '~/styles/utils'

import {
  DRAWER_PUSH_BACK_OFFSET,
  DRAWER_PUSH_BACK_SCALE,
  DRAWER_TRANSITION_DURATION,
} from './const'
import { drawerStack } from './drawerStack'
import { FormDrawerProps } from './types'
import { useDrawerStack } from './useDrawerStack'
import { useFocusTrap } from './useFocusTrap'

type DrawerState = 'unmounted' | 'mounting' | 'open' | 'closing'

export type BaseDrawerProps = {
  isOpen: boolean
  title: ReactNode
  children: ReactNode
  onClose: () => void
  onExited?: () => void
  onEntered?: (container: HTMLElement) => void
  className?: string
  actions?: ReactNode
  actionsClassName?: string
  withPadding?: boolean
  fullContentHeight?: boolean
  form?: FormDrawerProps
}

export const BASE_DRAWER_TEST_ID = 'base-drawer'
export const BASE_DRAWER_BACKDROP_TEST_ID = 'base-drawer-backdrop'
export const BASE_DRAWER_PAPER_TEST_ID = 'base-drawer-paper'
export const BASE_DRAWER_HEADER_TEST_ID = 'base-drawer-header'
export const BASE_DRAWER_CLOSE_BUTTON_TEST_ID = 'base-drawer-close-button'
export const BASE_DRAWER_CONTENT_TEST_ID = 'base-drawer-content'
export const BASE_DRAWER_ACTIONS_TEST_ID = 'base-drawer-actions'

export const BaseDrawer = ({
  isOpen,
  title,
  children,
  onClose,
  onExited,
  onEntered,
  className,
  actions,
  actionsClassName,
  withPadding = true,
  fullContentHeight,
  form,
}: BaseDrawerProps) => {
  const [state, setState] = useState<DrawerState>('unmounted')
  const paperRef = useRef<HTMLDivElement>(null)
  const closeButtonRef = useRef<HTMLButtonElement>(null)
  const exitedRef = useRef(false)

  const isInStack = state === 'mounting' || state === 'open'
  const { depthFromTop, isTopmost, isBottommost, zIndex } = useDrawerStack(isInStack)

  const { handleOpening, handleEntered, handleClosing } = useFocusTrap({
    containerRef: paperRef,
    isActive: state === 'open' && isTopmost,
    onEntered,
    closeButtonRef,
  })

  const handleExit = useCallback(() => {
    if (exitedRef.current) return
    exitedRef.current = true
    setState('unmounted')
    onExited?.()
  }, [onExited])

  // State machine: isOpen drives transitions
  useEffect(() => {
    if (isOpen) {
      if (state === 'unmounted') {
        exitedRef.current = false
        handleOpening()
        setState('mounting')
      }
    } else {
      if (state === 'open') {
        handleClosing()
        setState('closing')
      } else if (state === 'mounting') {
        handleExit()
      }
    }
  }, [isOpen, state, handleExit, handleOpening, handleClosing])

  // Trigger enter animation after mount (double-rAF for reliable CSS transition)
  useEffect(() => {
    if (state !== 'mounting') return

    let raf2: number

    const raf1 = requestAnimationFrame(() => {
      raf2 = requestAnimationFrame(() => {
        setState('open')
      })
    })

    return () => {
      cancelAnimationFrame(raf1)
      cancelAnimationFrame(raf2)
    }
  }, [state])

  // Fallback timeout in case transitionEnd doesn't fire
  useEffect(() => {
    if (state !== 'closing') return

    const timeout = setTimeout(handleExit, DRAWER_TRANSITION_DURATION + 100)

    return () => clearTimeout(timeout)
  }, [state, handleExit])

  // Handle CSS transition end for both enter and exit animations
  const enteredFiredRef = useRef(false)

  useEffect(() => {
    if (state === 'mounting') {
      enteredFiredRef.current = false
    }
  }, [state])

  const handleTransitionEnd = useCallback(
    (e: React.TransitionEvent) => {
      if (e.target !== paperRef.current || e.propertyName !== 'transform') return

      if (state === 'closing') {
        handleExit()
      } else if (state === 'open' && !enteredFiredRef.current) {
        enteredFiredRef.current = true
        handleEntered()
      }
    },
    [state, handleExit, handleEntered],
  )

  // Close this drawer when clearAll is called (e.g. on browser navigation)
  useEffect(() => {
    if (state !== 'open' && state !== 'mounting') return

    return drawerStack.onClear(() => onClose())
  }, [state, onClose])

  // ESC key closes topmost drawer only
  useEffect(() => {
    if (state !== 'open' || !isTopmost) return

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose()
      }
    }

    document.addEventListener('keydown', handleKeyDown)

    return () => document.removeEventListener('keydown', handleKeyDown)
  }, [state, isTopmost, onClose])

  if (state === 'unmounted') return null

  // Push-back transforms for stacked drawers
  // Scale and offset both diminish so deep stacks don't overflow
  const isPushedBack = state === 'open' && !isTopmost
  const scaleStep = 1 - DRAWER_PUSH_BACK_SCALE // 0.04
  const scale = isPushedBack ? Math.max(0.88, 1 - depthFromTop * scaleStep) : 1
  // Offset: sum of diminishing series (50, 25, 12.5, …) capped at ~100px total
  let offset = 0

  if (isPushedBack) {
    for (let i = 0; i < depthFromTop; i++) {
      offset += DRAWER_PUSH_BACK_OFFSET / Math.pow(2, i)
    }
  }

  const getPaperTransform = () => {
    if (state !== 'open') return 'translateX(100%)'
    if (isPushedBack) return `scale(${scale}) translateX(-${offset}px)`

    return 'translateX(0)'
  }

  const paperTransform = getPaperTransform()

  const renderContent = () => (
    <>
      {/* Content */}
      <div
        className={tw(
          'overflow-auto',
          fullContentHeight && 'h-full',
          withPadding && 'px-4 pb-20 pt-12 md:px-12',
        )}
        data-test={BASE_DRAWER_CONTENT_TEST_ID}
      >
        {children}
      </div>

      {/* Sticky bottom bar */}
      {!!actions && (
        <div
          className={tw(
            'sticky bottom-0 box-border flex items-center justify-end bg-white px-4 shadow-t md:px-12',
            actionsClassName,
          )}
          data-test={BASE_DRAWER_ACTIONS_TEST_ID}
        >
          {actions}
        </div>
      )}
    </>
  )

  return createPortal(
    <div
      className="fixed inset-0"
      style={{ zIndex }}
      role="presentation"
      data-test={BASE_DRAWER_TEST_ID}
    >
      {/* Backdrop - only the first drawer dims the page */}
      <div
        className={tw(
          'absolute inset-0 transition-opacity duration-300',
          isBottommost ? 'bg-grey-700/40' : 'bg-transparent',
          state === 'open' ? 'opacity-100' : 'opacity-0',
        )}
        onClick={isTopmost ? onClose : undefined}
        aria-hidden="true"
        data-test={BASE_DRAWER_BACKDROP_TEST_ID}
      />

      {/* Paper */}
      <div
        ref={paperRef}
        role="dialog"
        aria-modal="true"
        data-test={BASE_DRAWER_PAPER_TEST_ID}
        className={tw(
          'absolute bottom-0 right-0 top-0 flex w-full max-w-[816px] flex-col overflow-hidden rounded-l-xl bg-white shadow-xl',
          'origin-right transition-[transform,border-radius] duration-300 ease-[cubic-bezier(0.32,0.72,0,1)]',
          'md:w-[calc(100vw-48px)]',
          !!actions && 'grid grid-rows-[64px_1fr_64px]',
          className,
        )}
        style={{ transform: paperTransform }}
        onTransitionEnd={handleTransitionEnd}
      >
        {/* Dimming overlay for pushed-back drawers */}
        {isPushedBack && (
          <div className="pointer-events-none absolute inset-0 z-30 rounded-xl bg-grey-700/20" />
        )}

        {/* Header */}
        <div
          className="sticky top-0 z-20 flex h-nav min-h-nav items-center justify-between bg-white px-4 py-0 shadow-b md:px-12"
          data-test={BASE_DRAWER_HEADER_TEST_ID}
        >
          {typeof title === 'string' ? (
            <Typography variant="bodyHl" color="textSecondary" noWrap>
              {title}
            </Typography>
          ) : (
            title
          )}
          <Button
            ref={closeButtonRef}
            icon="close"
            variant="quaternary"
            onClick={onClose}
            data-test={BASE_DRAWER_CLOSE_BUTTON_TEST_ID}
          />
        </div>

        {/* Content + Sticky bottom bar, wrapped in form when form prop is provided */}
        {form ? (
          <form
            id={form.id}
            onSubmit={(e) => {
              e.preventDefault()
              form.submit()
            }}
            className="contents"
          >
            {renderContent()}
          </form>
        ) : (
          renderContent()
        )}
      </div>
    </div>,
    document.body,
  )
}
