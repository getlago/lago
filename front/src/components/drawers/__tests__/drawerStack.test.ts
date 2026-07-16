import { drawerStack } from '../drawerStack'

// The real drawerStack.ts uses import.meta.hot which Jest cannot handle,
// so we use the __mocks__/drawerStack.ts implementation for testing.
jest.mock('../drawerStack')

describe('drawerStack', () => {
  beforeEach(() => {
    // Clean up any leftover state
    const snapshot = drawerStack.getSnapshot()

    snapshot.forEach((id) => drawerStack.remove(id))
  })

  describe('GIVEN the stack is empty', () => {
    describe('WHEN getSnapshot is called', () => {
      it('THEN should return an empty array', () => {
        expect(drawerStack.getSnapshot()).toEqual([])
      })
    })

    describe('WHEN a drawer is pushed', () => {
      it('THEN should add the drawer to the stack', () => {
        drawerStack.push('drawer-1')

        expect(drawerStack.getSnapshot()).toEqual(['drawer-1'])
      })

      it('THEN should set body overflow to hidden', () => {
        drawerStack.push('drawer-1')

        expect(document.body.style.overflow).toBe('hidden')
      })
    })
  })

  describe('GIVEN the stack has drawers', () => {
    beforeEach(() => {
      drawerStack.push('drawer-1')
      drawerStack.push('drawer-2')
    })

    describe('WHEN pushing a duplicate drawer', () => {
      it('THEN should not add it again', () => {
        drawerStack.push('drawer-1')

        expect(drawerStack.getSnapshot()).toEqual(['drawer-1', 'drawer-2'])
      })
    })

    describe('WHEN pushing a new drawer', () => {
      it('THEN should append it to the stack', () => {
        drawerStack.push('drawer-3')

        expect(drawerStack.getSnapshot()).toEqual(['drawer-1', 'drawer-2', 'drawer-3'])
      })
    })

    describe('WHEN removing a drawer', () => {
      it('THEN should remove it from the stack', () => {
        drawerStack.remove('drawer-1')

        expect(drawerStack.getSnapshot()).toEqual(['drawer-2'])
      })

      it('THEN should keep body overflow hidden if stack is not empty', () => {
        drawerStack.remove('drawer-1')

        expect(document.body.style.overflow).toBe('hidden')
      })
    })

    describe('WHEN removing a drawer that is not in the stack', () => {
      it('THEN should not modify the stack', () => {
        drawerStack.remove('nonexistent')

        expect(drawerStack.getSnapshot()).toEqual(['drawer-1', 'drawer-2'])
      })
    })

    describe('WHEN removing all drawers', () => {
      it('THEN should restore body overflow', () => {
        drawerStack.remove('drawer-1')
        drawerStack.remove('drawer-2')

        expect(document.body.style.overflow).toBe('')
      })
    })
  })

  describe('GIVEN clearAll is called', () => {
    describe('WHEN the stack has drawers', () => {
      beforeEach(() => {
        drawerStack.push('drawer-1')
        drawerStack.push('drawer-2')
        drawerStack.push('drawer-3')
      })

      it('THEN should remove all drawers from the stack', () => {
        drawerStack.clearAll()

        expect(drawerStack.getSnapshot()).toEqual([])
      })

      it('THEN should restore body overflow', () => {
        drawerStack.clearAll()

        expect(document.body.style.overflow).toBe('')
      })

      it('THEN should notify listeners', () => {
        const listener = jest.fn()

        drawerStack.subscribe(listener)
        drawerStack.clearAll()

        expect(listener).toHaveBeenCalledTimes(1)
      })

      it('THEN should call onClear callbacks before clearing', () => {
        const onClear = jest.fn()

        drawerStack.onClear(onClear)
        drawerStack.clearAll()

        expect(onClear).toHaveBeenCalledTimes(1)
      })
    })

    describe('WHEN the stack is empty', () => {
      it('THEN should not notify listeners', () => {
        const listener = jest.fn()

        drawerStack.subscribe(listener)
        drawerStack.clearAll()

        expect(listener).not.toHaveBeenCalled()
      })

      it('THEN should not call onClear callbacks', () => {
        const onClear = jest.fn()

        drawerStack.onClear(onClear)
        drawerStack.clearAll()

        expect(onClear).not.toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN an onClear callback is registered', () => {
    describe('WHEN the callback is unregistered', () => {
      it('THEN should no longer be called on clearAll', () => {
        drawerStack.push('drawer-1')

        const onClear = jest.fn()
        const unregister = drawerStack.onClear(onClear)

        unregister()
        drawerStack.clearAll()

        expect(onClear).not.toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN a listener is subscribed', () => {
    describe('WHEN a drawer is pushed', () => {
      it('THEN should notify the listener', () => {
        const listener = jest.fn()

        drawerStack.subscribe(listener)
        drawerStack.push('drawer-1')

        expect(listener).toHaveBeenCalledTimes(1)
      })
    })

    describe('WHEN a drawer is removed', () => {
      it('THEN should notify the listener', () => {
        drawerStack.push('drawer-1')

        const listener = jest.fn()

        drawerStack.subscribe(listener)
        drawerStack.remove('drawer-1')

        expect(listener).toHaveBeenCalledTimes(1)
      })
    })

    describe('WHEN the listener is unsubscribed', () => {
      it('THEN should no longer be notified', () => {
        const listener = jest.fn()
        const unsubscribe = drawerStack.subscribe(listener)

        unsubscribe()
        drawerStack.push('drawer-1')

        expect(listener).not.toHaveBeenCalled()
      })
    })
  })
})
