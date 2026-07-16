import { renderHook } from '@testing-library/react'

import { CLOSE_PARAMS } from '../const'
import { useDialogActions } from '../useDialogActions'

// Mock the useInternationalization hook
jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => {
      if (key === 'text_6244277fe0975300fe3fb94a') return 'Cancel'
      if (key === 'text_62f50d26c989ab03196884ae') return 'Close'
      return key
    },
  }),
}))

describe('useDialogActions', () => {
  const createMockModal = () => ({
    id: 'test-modal-id',
    resolve: jest.fn(),
    reject: jest.fn(),
    hide: jest.fn(),
    visible: true,
    remove: jest.fn(),
    show: jest.fn(),
    keepMounted: false,
    resolveHide: jest.fn(),
  })

  describe('handleCancel', () => {
    it('resolves with CLOSE_PARAMS and hides modal', async () => {
      const mockModal = createMockModal()
      const mockOnAction = jest.fn()

      const { result } = renderHook(() =>
        useDialogActions({
          modal: mockModal,
          onAction: mockOnAction,
          cancelOrCloseText: 'close',
          closeOnError: true,
        }),
      )

      await result.current.handleCancel()

      expect(mockModal.resolve).toHaveBeenCalledWith(CLOSE_PARAMS)
      expect(mockModal.hide).toHaveBeenCalled()
    })
  })

  describe('handleContinue', () => {
    it('calls onAction and resolves on success', async () => {
      const mockModal = createMockModal()
      const mockResult = { reason: 'success', params: { data: 'test' } }
      const mockOnAction = jest.fn().mockResolvedValue(mockResult)

      const { result } = renderHook(() =>
        useDialogActions({
          modal: mockModal,
          onAction: mockOnAction,
          cancelOrCloseText: 'close',
          closeOnError: true,
        }),
      )

      await result.current.handleContinue()

      expect(mockOnAction).toHaveBeenCalled()
      expect(mockModal.resolve).toHaveBeenCalledWith(mockResult)
      expect(mockModal.hide).toHaveBeenCalled()
    })

    it('rejects with error object when onAction throws', async () => {
      const mockModal = createMockModal()
      const mockError = new Error('Test error')
      const mockOnAction = jest.fn().mockRejectedValue(mockError)

      const { result } = renderHook(() =>
        useDialogActions({
          modal: mockModal,
          onAction: mockOnAction,
          cancelOrCloseText: 'close',
          closeOnError: true,
        }),
      )

      await result.current.handleContinue()

      expect(mockOnAction).toHaveBeenCalled()
      expect(mockModal.reject).toHaveBeenCalledWith({
        reason: 'error',
        error: mockError,
      })
    })

    it('hides modal after error when closeOnError is true', async () => {
      const mockModal = createMockModal()
      const mockError = new Error('Test error')
      const mockOnAction = jest.fn().mockRejectedValue(mockError)

      const { result } = renderHook(() =>
        useDialogActions({
          modal: mockModal,
          onAction: mockOnAction,
          cancelOrCloseText: 'close',
          closeOnError: true,
        }),
      )

      await result.current.handleContinue()

      expect(mockModal.hide).toHaveBeenCalled()
    })

    it('keeps modal open after error when closeOnError is false and does not reject', async () => {
      const mockModal = createMockModal()
      const mockError = new Error('Test error')
      const mockOnAction = jest.fn().mockRejectedValue(mockError)

      const { result } = renderHook(() =>
        useDialogActions({
          modal: mockModal,
          onAction: mockOnAction,
          cancelOrCloseText: 'close',
          closeOnError: false,
        }),
      )

      await result.current.handleContinue()

      expect(mockModal.reject).not.toHaveBeenCalled()
      expect(mockModal.hide).not.toHaveBeenCalled()
    })

    it('calls onError callback when closeOnError is false and error occurs', async () => {
      const mockModal = createMockModal()
      const mockError = new Error('Test error')
      const mockOnAction = jest.fn().mockRejectedValue(mockError)
      const mockOnError = jest.fn()

      const { result } = renderHook(() =>
        useDialogActions({
          modal: mockModal,
          onAction: mockOnAction,
          cancelOrCloseText: 'close',
          closeOnError: false,
          onError: mockOnError,
        }),
      )

      await result.current.handleContinue()

      expect(mockOnError).toHaveBeenCalledWith(mockError)
      expect(mockModal.reject).not.toHaveBeenCalled()
      expect(mockModal.hide).not.toHaveBeenCalled()
    })
  })

  describe('closeText', () => {
    it('returns correct translation for cancel option', () => {
      const mockModal = createMockModal()
      const mockOnAction = jest.fn()

      const { result } = renderHook(() =>
        useDialogActions({
          modal: mockModal,
          onAction: mockOnAction,
          cancelOrCloseText: 'cancel',
          closeOnError: true,
        }),
      )

      expect(result.current.closeText).toBe('Cancel')
    })

    it('returns correct translation for close option', () => {
      const mockModal = createMockModal()
      const mockOnAction = jest.fn()

      const { result } = renderHook(() =>
        useDialogActions({
          modal: mockModal,
          onAction: mockOnAction,
          cancelOrCloseText: 'close',
          closeOnError: true,
        }),
      )

      expect(result.current.closeText).toBe('Close')
    })
  })

  describe('Integration', () => {
    it('handles void onAction return with default success response', async () => {
      const mockModal = createMockModal()
      const mockOnAction = jest.fn()

      const { result } = renderHook(() =>
        useDialogActions({
          modal: mockModal,
          onAction: mockOnAction,
          cancelOrCloseText: 'close',
          closeOnError: true,
        }),
      )

      await result.current.handleContinue()

      expect(mockOnAction).toHaveBeenCalled()
      expect(mockModal.resolve).toHaveBeenCalledWith({ reason: 'success' })
      expect(mockModal.hide).toHaveBeenCalled()
    })
  })
})
