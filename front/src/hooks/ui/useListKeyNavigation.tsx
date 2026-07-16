import { KeyboardEventHandler, useCallback } from 'react'

export interface useKeyNavigationOptions {
  getElmId: (id: string | number) => string
  navigate?: (id: string | number) => void
  disabled?: boolean
}
type UseKeyNavigation<T = HTMLDivElement> = (options: useKeyNavigationOptions) => {
  onKeyDown: KeyboardEventHandler<T>
}

// Allow to navigate in a list
export const useListKeysNavigation: UseKeyNavigation = ({
  getElmId,
  disabled = false,
  navigate,
}) => {
  return {
    onKeyDown: useCallback(
      (e) => {
        if (disabled) {
          return
        }

        const getIndex = (document.activeElement?.id || '').split(getElmId(''))[1]
        let nextId = null

        if (['ArrowDown', 'KeyJ'].includes(e.code)) {
          e.stopPropagation()
          nextId = getElmId(parseInt(getIndex) + 1)
        }

        if (['ArrowUp', 'KeyK'].includes(e.code)) {
          e.stopPropagation()
          nextId = getElmId(parseInt(getIndex) - 1)
        }

        if (['Enter'].includes(e.code) && !!navigate) {
          e.stopPropagation()
          const id = getElmId(parseInt(getIndex))
          const elementToNavigateTo = document.getElementById(id)
          const realId = elementToNavigateTo?.dataset.id

          if (!!realId) {
            navigate(realId)
          }
          return
        }

        if (!nextId) return

        const elementToFocus = document.getElementById(nextId)

        elementToFocus && elementToFocus.focus()
      },
      [disabled, getElmId, navigate],
    ),
  }
}
