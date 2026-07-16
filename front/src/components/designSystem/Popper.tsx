import ClickAwayListener from '@mui/material/ClickAwayListener'
import MuiPopper, { type PopperProps as MUIPopperProps } from '@mui/material/Popper'
import {
  cloneElement,
  forwardRef,
  MouseEvent,
  ReactElement,
  ReactNode,
  useCallback,
  useEffect,
  useImperativeHandle,
  useRef,
  useState,
} from 'react'

import { tw } from '~/styles/utils'

export const POPPER_WRAPPER_CLASSES =
  'overflow-auto scroll-smooth rounded-xl border border-grey-200 bg-white shadow-md focus:outline-none not-last-child:mb-1'

// Tracks the currently-open popper per group name so that opening one popper
// closes any other open popper sharing the same `popperGroupName` (single-open
// behavior). Poppers without a group name stay fully independent.
const openPopperRegistry = new Map<string, () => void>()

// Read-only accessor for the group registry. Exposed so tests can assert the
// unmount cleanup actually drops the entry (the cleanup is otherwise not
// DOM-observable, since a stale close fn on an unmounted popper is a no-op).
export const isPopperGroupTracked = (groupName: string): boolean =>
  openPopperRegistry.has(groupName)

export interface PopperProps {
  className?: string
  opener?:
    ReactElement | (({ isOpen, onClick }: { isOpen: boolean; onClick: () => void }) => ReactElement)
  maxHeight?: number | string
  minWidth?: number
  PopperProps?: Pick<MUIPopperProps, 'placement' | 'modifiers' | 'disablePortal'>
  enableFlip?: boolean
  displayInDialog?: boolean
  popperGroupName?: string
  popperName?: string
  children: (({ closePopper }: { closePopper: () => void }) => ReactNode) | ReactNode
  onClickAway?: () => void
}

interface PopperRef {
  openPopper: () => unknown
  closePopper: () => unknown
}

export const Popper = forwardRef<PopperRef, PopperProps>(
  (
    {
      opener,
      PopperProps,
      maxHeight,
      children,
      className,
      minWidth,
      enableFlip = true,
      displayInDialog = false,
      onClickAway,
      popperGroupName,
    }: PopperProps,
    ref,
  ) => {
    const [isOpen, setIsOpen] = useState(false)
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const openerRef = useRef<any>(null)
    const cardRef = useRef<HTMLDivElement>(null)

    const updateIsOpen = useCallback(
      (open: boolean) => {
        setIsOpen(open)
      },
      [setIsOpen],
    )

    const toggle = useCallback(() => {
      updateIsOpen(!isOpen)
      if (!isOpen) {
        setTimeout(() => {
          cardRef?.current?.focus()
        }, 200)
      }
    }, [updateIsOpen, isOpen])

    const onClickAwayProxy = useCallback(() => {
      updateIsOpen(false)
      onClickAway && onClickAway()
    }, [updateIsOpen, onClickAway])

    const close = useCallback(() => updateIsOpen(false), [updateIsOpen])

    // Single-open coordination: when this popper opens, close any other open
    // popper in the same group; keep the registry in sync as it opens/closes.
    useEffect(() => {
      if (!popperGroupName) return

      if (isOpen) {
        const previousClose = openPopperRegistry.get(popperGroupName)

        if (previousClose && previousClose !== close) {
          previousClose()
        }
        openPopperRegistry.set(popperGroupName, close)
      } else if (openPopperRegistry.get(popperGroupName) === close) {
        openPopperRegistry.delete(popperGroupName)
      }
    }, [isOpen, popperGroupName, close])

    // Stop tracking this popper on unmount so a stale close fn never lingers.
    useEffect(() => {
      return () => {
        if (popperGroupName && openPopperRegistry.get(popperGroupName) === close) {
          openPopperRegistry.delete(popperGroupName)
        }
      }
    }, [popperGroupName, close])

    useImperativeHandle(ref, () => ({
      openPopper: () => updateIsOpen(true),
      closePopper: () => updateIsOpen(false),
    }))

    const getOpener = () => {
      if (typeof opener === 'function') {
        return cloneElement(opener({ isOpen, onClick: toggle }), {
          onClick: (e: MouseEvent<HTMLDivElement>) => {
            const element = opener({ isOpen, onClick: toggle })

            element?.props?.onClick && element.props.onClick(e)
            // Only toggle if the event wasn't prevented
            if (!e.isPropagationStopped()) {
              toggle()
            }
          },
          ref: openerRef,
        })
      }

      if (!!opener) {
        return cloneElement(opener, { onClick: toggle, ref: openerRef })
      }

      return null
    }

    const getMaxHeight = () => {
      if (!maxHeight) return '90vh'
      return typeof maxHeight === 'string' ? maxHeight : `${maxHeight}px`
    }

    return (
      <ClickAwayListener onClickAway={onClickAwayProxy}>
        <div className={tw(className)}>
          {getOpener()}
          <MuiPopper
            className={tw(displayInDialog ? 'z-dialog' : 'z-popper')}
            style={{ minWidth: `${minWidth ?? openerRef?.current?.offsetWidth ?? 0}px` }}
            onKeyDown={(e) => {
              if (e.code === 'Escape') {
                updateIsOpen(false)
              }
            }}
            open={isOpen}
            anchorEl={openerRef.current}
            modifiers={[
              {
                name: 'flip',
                enabled: enableFlip,
              },
              {
                name: 'offset',
                enabled: true,
                options: {
                  offset: [0, 8],
                },
              },
            ]}
            {...PopperProps}
          >
            <div
              ref={cardRef}
              className={tw(POPPER_WRAPPER_CLASSES)}
              style={{
                maxHeight: getMaxHeight(),
              }}
            >
              {typeof children === 'function'
                ? children({ closePopper: () => updateIsOpen(false) })
                : children}
            </div>
          </MuiPopper>
        </div>
      </ClickAwayListener>
    )
  },
)

Popper.displayName = 'Popper'
