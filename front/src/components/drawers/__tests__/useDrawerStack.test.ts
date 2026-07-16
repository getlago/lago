import { renderHook } from '@testing-library/react'

import { DRAWER_BASE_Z_INDEX } from '../const'
import { drawerStack } from '../drawerStack'
import { useDrawerStack } from '../useDrawerStack'

jest.mock('../drawerStack')

describe('useDrawerStack', () => {
  beforeEach(() => {
    const snapshot = drawerStack.getSnapshot()

    snapshot.forEach((id) => drawerStack.remove(id))
  })

  describe('GIVEN a single active drawer', () => {
    describe('WHEN the drawer joins the stack', () => {
      it('THEN should be topmost and bottommost', () => {
        const { result } = renderHook(() => useDrawerStack(true))

        expect(result.current.isTopmost).toBe(true)
        expect(result.current.isBottommost).toBe(true)
        expect(result.current.depthFromTop).toBe(0)
      })

      it('THEN should have the base z-index', () => {
        const { result } = renderHook(() => useDrawerStack(true))

        expect(result.current.zIndex).toBe(DRAWER_BASE_Z_INDEX)
      })
    })
  })

  describe('GIVEN multiple active drawers', () => {
    describe('WHEN two drawers are in the stack', () => {
      it('THEN the first should be bottommost and pushed back', () => {
        const { result: first } = renderHook(() => useDrawerStack(true))
        const { result: second } = renderHook(() => useDrawerStack(true))

        expect(first.current.isBottommost).toBe(true)
        expect(first.current.isTopmost).toBe(false)
        expect(first.current.depthFromTop).toBe(1)

        expect(second.current.isTopmost).toBe(true)
        expect(second.current.isBottommost).toBe(false)
        expect(second.current.depthFromTop).toBe(0)
      })

      it('THEN z-index should increase for each drawer', () => {
        const { result: first } = renderHook(() => useDrawerStack(true))
        const { result: second } = renderHook(() => useDrawerStack(true))

        expect(second.current.zIndex).toBeGreaterThan(first.current.zIndex)
      })
    })
  })

  describe('GIVEN a drawer becomes inactive', () => {
    describe('WHEN isActive changes to false', () => {
      it('THEN should remove itself from the stack', () => {
        const { result, rerender } = renderHook(({ isActive }) => useDrawerStack(isActive), {
          initialProps: { isActive: true },
        })

        expect(result.current.isTopmost).toBe(true)

        rerender({ isActive: false })

        // After removal, defaults apply
        expect(result.current.depthFromTop).toBe(0)
      })
    })
  })

  describe('GIVEN the hook unmounts', () => {
    describe('WHEN the component is destroyed', () => {
      it('THEN should clean up from the stack', () => {
        const { unmount } = renderHook(() => useDrawerStack(true))

        expect(drawerStack.getSnapshot().length).toBe(1)

        unmount()

        expect(drawerStack.getSnapshot().length).toBe(0)
      })
    })
  })
})
