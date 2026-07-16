import { tw } from 'lago-design-system'
import { CSSProperties, forwardRef, ReactNode, useImperativeHandle, useRef } from 'react'

const CTASection = ({ children, className }: { children: ReactNode; className?: string }) => {
  return (
    <section
      className={tw(
        'no-scrollbar::-webkit-scrollbar flex flex-row flex-nowrap items-center gap-4 overflow-x-auto p-4 no-scrollbar *:shrink-0',
        className,
      )}
    >
      {children}
    </section>
  )
}

export type ListSectionRef = {
  updateView: (direction: 'forward' | 'backward') => void
  setActiveRow: (id: string) => void
}

type ListSectionProps = {
  leftSide: ReactNode
  rightSide: ReactNode
  shouldDisplayRightSide: boolean
  sectionHeight?: CSSProperties['height']
}

const ListSection = forwardRef<ListSectionRef, ListSectionProps>(
  ({ leftSide, rightSide, shouldDisplayRightSide, sectionHeight }, ref) => {
    const logListRef = useRef<HTMLDivElement>(null)

    const updateView = (direction: 'forward' | 'backward') => {
      if (logListRef.current) {
        logListRef.current.style.transform = `translateX(${direction === 'forward' ? '-50%' : '0%'})`
      }
    }

    const setActiveRow = (id: string) => {
      if (logListRef.current) {
        const selectedRows = logListRef.current.querySelectorAll('tr[data-state="selected"]')

        selectedRows.forEach((row) => {
          row.removeAttribute('data-state')
        })

        const element = logListRef.current.querySelector(`tr[data-id="${id}"]`) as HTMLElement

        element?.setAttribute('data-state', 'selected')
      }
    }

    useImperativeHandle(ref, () => {
      return {
        updateView,
        setActiveRow,
      }
    })

    return (
      <section
        className="relative flex flex-1 flex-row overflow-hidden md:min-h-20"
        style={sectionHeight ? { height: sectionHeight } : undefined}
      >
        <div
          ref={logListRef}
          className="left-0 top-0 h-full w-[200%] transition-transform md:w-full md:!translate-x-0"
          style={{
            position: shouldDisplayRightSide ? 'absolute' : 'relative',
            transform: shouldDisplayRightSide ? 'translateX(-50%)' : 'translateX(0%)',
          }}
        >
          <div className="flex h-full flex-1 flex-row items-stretch justify-start overflow-hidden">
            <div
              className={tw(
                shouldDisplayRightSide
                  ? 'h-full w-1/2 flex-1 overflow-auto'
                  : 'h-full w-full overflow-auto',
              )}
            >
              {leftSide}
            </div>
            {shouldDisplayRightSide && (
              <div className="w-1/2 flex-1 overflow-auto shadow-l">{rightSide}</div>
            )}
          </div>
        </div>
      </section>
    )
  },
)

ListSection.displayName = 'ListSection'

export const LogsLayout = {
  CTASection,
  ListSection,
}
