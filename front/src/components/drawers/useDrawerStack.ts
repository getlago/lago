import { useEffect, useId, useRef, useSyncExternalStore } from 'react'

import { DRAWER_BASE_Z_INDEX } from './const'
import { drawerStack } from './drawerStack'

export const useDrawerStack = (isActive: boolean) => {
  const id = useId()
  const lastZIndexRef = useRef(DRAWER_BASE_Z_INDEX)

  const stack = useSyncExternalStore(drawerStack.subscribe, drawerStack.getSnapshot)

  useEffect(() => {
    if (isActive) {
      drawerStack.push(id)
    } else {
      drawerStack.remove(id)
    }

    return () => {
      drawerStack.remove(id)
    }
  }, [id, isActive])

  const stackIndex = stack.indexOf(id)
  const depthFromTop = stackIndex === -1 ? 0 : stack.length - 1 - stackIndex
  const isTopmost = stackIndex === -1 ? true : depthFromTop === 0
  const isBottommost = stackIndex === 0

  // Preserve z-index during exit animation so the closing drawer
  // doesn't drop behind the ones below it
  const zIndex = stackIndex === -1 ? lastZIndexRef.current : DRAWER_BASE_Z_INDEX + stackIndex * 2

  if (stackIndex !== -1) {
    lastZIndexRef.current = zIndex
  }

  return { depthFromTop, isTopmost, isBottommost, zIndex }
}
