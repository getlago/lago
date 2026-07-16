type Listener = () => void

const state: { stack: string[]; listeners: Set<Listener>; clearCallbacks: Set<Listener> } = {
  stack: [],
  listeners: new Set(),
  clearCallbacks: new Set(),
}

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
