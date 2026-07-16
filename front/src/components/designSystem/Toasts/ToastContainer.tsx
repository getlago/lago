import { useReactiveVar } from '@apollo/client'
import { createRef, RefObject, useEffect, useRef } from 'react'

import { removeAllToasts, toastsVar } from '~/core/apolloClient'

import { Toast } from './Toast'

const MAX_DISPLAYED_ITEMS = 3

type ToastRef = {
  closeToast: () => unknown
}

type ElementsRefs = Record<string, RefObject<ToastRef>>

export const ToastContainer = () => {
  const toasts = useReactiveVar(toastsVar)
  const elementsRefs = useRef<ElementsRefs>({})

  useEffect(() => {
    // Add a new ref or use existant one for each toast
    elementsRefs.current = toasts.reduce((acc, { id }) => {
      acc[id] = elementsRefs.current[id] || createRef<ToastRef>()

      return acc
    }, {} as ElementsRefs)

    // Get the MAX_DISPLAYED_ITEMS toast that will be displayed
    const elementsToDisplay = toasts.slice(0, MAX_DISPLAYED_ITEMS).map(({ id }) => id)

    // Ask child to remove itself for all the toast that must not be displayed anymore
    Object.keys(elementsRefs.current).map((id) => {
      if (!elementsToDisplay.includes(id)) {
        if (elementsRefs.current[id]?.current?.closeToast) {
          elementsRefs.current[id].current.closeToast()
        }
      }
    })
  }, [toasts])

  useEffect(() => {
    // This is to avoid persistance on the toasts
    return () => removeAllToasts()
  }, [])

  return (
    <div className="pointer-events-none fixed bottom-0 left-0 z-toast mb-4 ml-4 cursor-default">
      {toasts.map((toast) => (
        <Toast key={toast.id} ref={elementsRefs.current[toast.id]} toast={toast} />
      ))}
    </div>
  )
}
