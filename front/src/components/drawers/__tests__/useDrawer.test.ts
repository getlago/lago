import NiceModal from '@ebay/nice-modal-react'
import { renderHook } from '@testing-library/react'

import { CLOSE_DRAWER_PARAMS } from '../const'
import { useDrawer, useFormDrawer } from '../useDrawer'

jest.mock('../drawerStack')

// Mock NiceModal
const mockShow = jest.fn().mockResolvedValue({ reason: 'close' })
const mockHide = jest.fn()
const mockResolve = jest.fn()

jest.mock('@ebay/nice-modal-react', () => ({
  __esModule: true,
  default: {
    register: jest.fn(),
  },
  create: jest.fn((component: unknown) => component),
  unregister: jest.fn(),
  useModal: jest.fn(() => ({
    show: mockShow,
    hide: mockHide,
    resolve: mockResolve,
    reject: jest.fn(),
    remove: jest.fn(),
    visible: false,
  })),
}))

describe('useDrawer', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the hook is initialized', () => {
    describe('WHEN useDrawer is called', () => {
      it('THEN should register CentralizedDrawer with NiceModal', () => {
        renderHook(() => useDrawer())

        expect(NiceModal.register).toHaveBeenCalledWith(expect.any(String), expect.any(Function))
      })

      it('THEN should return open and close functions', () => {
        const { result } = renderHook(() => useDrawer())

        expect(result.current.open).toBeInstanceOf(Function)
        expect(result.current.close).toBeInstanceOf(Function)
      })
    })
  })

  describe('GIVEN open is called', () => {
    describe('WHEN opening a drawer with props', () => {
      it('THEN should call modal.show with the provided props', () => {
        const { result } = renderHook(() => useDrawer())
        const props = { title: 'Test', children: null }

        result.current.open(props)

        expect(mockShow).toHaveBeenCalledWith(props)
      })
    })
  })

  describe('GIVEN close is called', () => {
    describe('WHEN closing the drawer', () => {
      it('THEN should resolve with CLOSE_DRAWER_PARAMS and hide', () => {
        const { result } = renderHook(() => useDrawer())

        result.current.close()

        expect(mockResolve).toHaveBeenCalledWith(CLOSE_DRAWER_PARAMS)
        expect(mockHide).toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the hook unmounts', () => {
    describe('WHEN the component is destroyed', () => {
      it('THEN should unregister from NiceModal', async () => {
        const { unregister } = jest.requireMock('@ebay/nice-modal-react')
        const { unmount } = renderHook(() => useDrawer())

        unmount()

        expect(unregister).toHaveBeenCalledWith(expect.any(String))
      })
    })
  })
})

describe('useFormDrawer', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the hook is initialized', () => {
    describe('WHEN useFormDrawer is called', () => {
      it('THEN should register FormDrawer with NiceModal', () => {
        renderHook(() => useFormDrawer())

        expect(NiceModal.register).toHaveBeenCalledWith(expect.any(String), expect.any(Function))
      })

      it('THEN should return open and close functions', () => {
        const { result } = renderHook(() => useFormDrawer())

        expect(result.current.open).toBeInstanceOf(Function)
        expect(result.current.close).toBeInstanceOf(Function)
      })
    })
  })

  describe('GIVEN close is called', () => {
    describe('WHEN closing the form drawer', () => {
      it('THEN should resolve with CLOSE_DRAWER_PARAMS and hide', () => {
        const { result } = renderHook(() => useFormDrawer())

        result.current.close()

        expect(mockResolve).toHaveBeenCalledWith(CLOSE_DRAWER_PARAMS)
        expect(mockHide).toHaveBeenCalled()
      })
    })
  })
})
