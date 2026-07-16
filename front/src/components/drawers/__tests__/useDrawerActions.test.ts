import { act, renderHook } from '@testing-library/react'

import { CLOSE_DRAWER_PARAMS } from '../const'
import { useDrawerActions } from '../useDrawerActions'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const createMockModal = () =>
  ({
    id: 'test-modal',
    visible: true,
    keepMounted: false,
    show: jest.fn(),
    hide: jest.fn(),
    resolve: jest.fn(),
    reject: jest.fn(),
    remove: jest.fn(),
    resolveHide: jest.fn(),
  }) as unknown as ReturnType<typeof import('@ebay/nice-modal-react').useModal>

describe('useDrawerActions', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the hook is initialized', () => {
    describe('WHEN cancelOrCloseText is "close"', () => {
      it('THEN should return a translated close text', () => {
        const modal = createMockModal()
        const { result } = renderHook(() =>
          useDrawerActions({
            modal,
            cancelOrCloseText: 'close',
            closeOnError: true,
          }),
        )

        expect(typeof result.current.closeText).toBe('string')
        expect(result.current.closeText.length).toBeGreaterThan(0)
      })
    })

    describe('WHEN cancelOrCloseText changes between "close" and "cancel"', () => {
      it('THEN should return different translated text for each', () => {
        const modal = createMockModal()
        const { result: closeResult } = renderHook(() =>
          useDrawerActions({
            modal,
            cancelOrCloseText: 'close',
            closeOnError: true,
          }),
        )
        const { result: cancelResult } = renderHook(() =>
          useDrawerActions({
            modal,
            cancelOrCloseText: 'cancel',
            closeOnError: true,
          }),
        )

        expect(closeResult.current.closeText).not.toBe(cancelResult.current.closeText)
      })
    })
  })

  describe('GIVEN handleCancel is called', () => {
    describe('WHEN the user cancels', () => {
      it('THEN should resolve with CLOSE_DRAWER_PARAMS and hide', () => {
        const modal = createMockModal()
        const { result } = renderHook(() =>
          useDrawerActions({
            modal,
            cancelOrCloseText: 'close',
            closeOnError: true,
          }),
        )

        act(() => {
          result.current.handleCancel()
        })

        expect(modal.resolve).toHaveBeenCalledWith(CLOSE_DRAWER_PARAMS)
        expect(modal.hide).toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN handleContinue is called', () => {
    describe('WHEN onAction is not provided', () => {
      it('THEN should return without resolving or hiding', async () => {
        const modal = createMockModal()
        const { result } = renderHook(() =>
          useDrawerActions({
            modal,
            cancelOrCloseText: 'close',
            closeOnError: true,
          }),
        )

        await act(async () => {
          await result.current.handleContinue()
        })

        expect(modal.resolve).not.toHaveBeenCalled()
        expect(modal.hide).not.toHaveBeenCalled()
      })
    })

    describe('WHEN onAction succeeds with a result', () => {
      it('THEN should resolve with the action result and hide', async () => {
        const modal = createMockModal()
        const actionResult = { reason: 'success' as const, params: { id: '123' } }
        const onAction = jest.fn().mockResolvedValue(actionResult)

        const { result } = renderHook(() =>
          useDrawerActions({
            modal,
            onAction,
            cancelOrCloseText: 'close',
            closeOnError: true,
          }),
        )

        await act(async () => {
          await result.current.handleContinue()
        })

        expect(modal.resolve).toHaveBeenCalledWith(actionResult)
        expect(modal.hide).toHaveBeenCalled()
      })
    })

    describe('WHEN onAction succeeds without returning a result', () => {
      it('THEN should resolve with default success reason', async () => {
        const modal = createMockModal()
        const onAction = jest.fn().mockResolvedValue(undefined)

        const { result } = renderHook(() =>
          useDrawerActions({
            modal,
            onAction,
            cancelOrCloseText: 'close',
            closeOnError: true,
          }),
        )

        await act(async () => {
          await result.current.handleContinue()
        })

        expect(modal.resolve).toHaveBeenCalledWith({ reason: 'success' })
        expect(modal.hide).toHaveBeenCalled()
      })
    })

    describe('WHEN onAction throws and closeOnError is true', () => {
      it('THEN should reject with the error and hide', async () => {
        const modal = createMockModal()
        const error = new Error('Action failed')
        const onAction = jest.fn().mockRejectedValue(error)

        const { result } = renderHook(() =>
          useDrawerActions({
            modal,
            onAction,
            cancelOrCloseText: 'close',
            closeOnError: true,
          }),
        )

        await act(async () => {
          await result.current.handleContinue()
        })

        expect(modal.reject).toHaveBeenCalledWith({
          reason: 'error',
          error,
        })
        expect(modal.hide).toHaveBeenCalled()
      })
    })

    describe('WHEN onAction throws and closeOnError is false', () => {
      it('THEN should call onError and not hide', async () => {
        const modal = createMockModal()
        const error = new Error('Action failed')
        const onAction = jest.fn().mockRejectedValue(error)
        const onError = jest.fn()

        const { result } = renderHook(() =>
          useDrawerActions({
            modal,
            onAction,
            cancelOrCloseText: 'close',
            closeOnError: false,
            onError,
          }),
        )

        await act(async () => {
          await result.current.handleContinue()
        })

        expect(onError).toHaveBeenCalledWith(error)
        expect(modal.reject).not.toHaveBeenCalled()
        expect(modal.hide).not.toHaveBeenCalled()
      })
    })
  })
})
