// Module-level pub/sub store that tracks which drawers are currently open, in order.
// It lives outside React so multiple drawer instances can coordinate their stacking
// (z-index, push-back transforms, topmost detection) without a context provider.
//
// The `subscribe` + `getSnapshot` API is designed for React's `useSyncExternalStore`,
// which is how `useDrawerStack` reactively reads the stack.
//
// It also centralizes the body scroll lock: `overflow: hidden` is applied when the
// first drawer opens and removed when the last one closes.

type Listener = () => void

type DrawerStackState = {
  stack: string[]
  listeners: Set<Listener>
  clearCallbacks: Set<Listener>
}

// Preserve state across HMR updates
const getState = (): DrawerStackState => {
  if (import.meta.hot) {
    if (!import.meta.hot.data.drawerStack) {
      import.meta.hot.data.drawerStack = {
        stack: [],
        listeners: new Set<Listener>(),
        clearCallbacks: new Set<Listener>(),
      }
    }

    return import.meta.hot.data.drawerStack as DrawerStackState
  }

  return { stack: [], listeners: new Set<Listener>(), clearCallbacks: new Set<Listener>() }
}

const state = getState()

const notify = () => {
  state.listeners.forEach((l) => l())
}

const updateBodyScroll = () => {
  document.body.style.overflow = state.stack.length > 0 ? 'hidden' : ''
}

export const drawerStack = {
  push(id: string) {
    if (!state.stack.includes(id)) {
      state.stack = [...state.stack, id]
      updateBodyScroll()
      notify()
    }
  },

  remove(id: string) {
    const index = state.stack.indexOf(id)

    if (index !== -1) {
      state.stack = [...state.stack.slice(0, index), ...state.stack.slice(index + 1)]
      updateBodyScroll()
      notify()
    }
  },

  subscribe(listener: Listener) {
    state.listeners.add(listener)

    return () => {
      state.listeners.delete(listener)
    }
  },

  onClear(callback: Listener) {
    state.clearCallbacks.add(callback)

    return () => {
      state.clearCallbacks.delete(callback)
    }
  },

  clearAll() {
    if (state.stack.length > 0) {
      state.clearCallbacks.forEach((cb) => cb())
      state.stack = []
      updateBodyScroll()
      notify()
    }
  },

  getSnapshot() {
    return state.stack
  },
}
