import { ReactNode, useEffect, useRef } from 'react'

interface InfiniteScrollProps {
  onBottom: () => void
  children: ReactNode
}

export const InfiniteScroll = ({ children, onBottom }: InfiniteScrollProps) => {
  const hiddenBottom = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting === true) {
          onBottom?.()
        }
      },
      { threshold: [0] },
    )

    let element: HTMLDivElement

    if (hiddenBottom.current) {
      observer.observe(hiddenBottom.current)
      element = hiddenBottom.current
    }

    return () => {
      if (element) {
        observer.unobserve(element)
      }
    }
  }, [hiddenBottom, onBottom])

  return (
    <div className="relative overflow-y-auto">
      {children}
      <div className="absolute inset-x-0 bottom-0 -z-10 h-10" ref={hiddenBottom} />
    </div>
  )
}
