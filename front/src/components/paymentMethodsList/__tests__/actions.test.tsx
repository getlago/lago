import { addToast } from '~/core/apolloClient'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import { createMockPaymentMethod } from '~/hooks/customer/__tests__/factories/PaymentMethod.factory'

import { generatePaymentMethodsActions } from '../actions'

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

jest.mock('~/core/utils/copyToClipboard', () => ({
  copyToClipboard: jest.fn(),
}))

describe('generatePaymentMethodsActions', () => {
  const mockTranslate = jest.fn((key: string) => key)
  const mockSetPaymentMethodAsDefault = jest.fn().mockResolvedValue(undefined)
  const mockOnDeletePaymentMethod = jest.fn()

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('WHEN generating actions', () => {
    it('THEN returns three actions', () => {
      const paymentMethod = createMockPaymentMethod()
      const actions = generatePaymentMethodsActions({
        item: paymentMethod,
        translate: mockTranslate,
        setPaymentMethodAsDefault: mockSetPaymentMethodAsDefault,
        onDeletePaymentMethod: mockOnDeletePaymentMethod,
      })

      const setAsDefaultAction = actions.find((action) => action.startIcon === 'star-filled')
      const copyAction = actions.find((action) => action.startIcon === 'duplicate')
      const deleteAction = actions.find((action) => action.startIcon === 'trash')

      expect(setAsDefaultAction).toBeDefined()
      expect(copyAction).toBeDefined()
      expect(deleteAction).toBeDefined()
    })

    it('THEN disables set as default action when payment method is default', () => {
      const paymentMethod = createMockPaymentMethod({ isDefault: true })
      const actions = generatePaymentMethodsActions({
        item: paymentMethod,
        translate: mockTranslate,
        setPaymentMethodAsDefault: mockSetPaymentMethodAsDefault,
        onDeletePaymentMethod: mockOnDeletePaymentMethod,
      })

      const setAsDefaultAction = actions.find((action) => action.startIcon === 'star-filled')

      expect(setAsDefaultAction).toBeDefined()
      expect(setAsDefaultAction?.disabled).toBe(true)
    })

    it('THEN disables set as default and delete actions when payment method is deleted', () => {
      const paymentMethod = createMockPaymentMethod({
        deletedAt: '2024-01-01T00:00:00Z',
      })
      const actions = generatePaymentMethodsActions({
        item: paymentMethod,
        translate: mockTranslate,
        setPaymentMethodAsDefault: mockSetPaymentMethodAsDefault,
        onDeletePaymentMethod: mockOnDeletePaymentMethod,
      })

      const setAsDefaultAction = actions.find((action) => action.startIcon === 'star-filled')
      const deleteAction = actions.find((action) => action.startIcon === 'trash')

      expect(setAsDefaultAction).toBeDefined()
      expect(setAsDefaultAction?.disabled).toBe(true)
      expect(deleteAction).toBeDefined()
      expect(deleteAction?.disabled).toBe(true)
    })
  })

  describe('WHEN executing set as default action', () => {
    it('THEN calls setPaymentMethodAsDefault with correct input and shows success toast', async () => {
      const paymentMethod = createMockPaymentMethod({ id: 'pm_test_001' })
      const actions = generatePaymentMethodsActions({
        item: paymentMethod,
        translate: mockTranslate,
        setPaymentMethodAsDefault: mockSetPaymentMethodAsDefault,
        onDeletePaymentMethod: mockOnDeletePaymentMethod,
      })

      const setAsDefaultAction = actions.find((action) => action.startIcon === 'star-filled')

      expect(setAsDefaultAction).toBeDefined()
      if (!setAsDefaultAction) return

      await setAsDefaultAction.onAction(paymentMethod)

      expect(mockSetPaymentMethodAsDefault).toHaveBeenCalledWith({ id: 'pm_test_001' })

      expect(addToast).toHaveBeenCalledWith(
        expect.objectContaining({
          severity: 'success',
        }),
      )
    })
  })

  describe('WHEN executing copy action', () => {
    it('THEN copies payment method id to clipboard and shows info toast', () => {
      const paymentMethod = createMockPaymentMethod({ id: 'pm_copy_001' })
      const actions = generatePaymentMethodsActions({
        item: paymentMethod,
        translate: mockTranslate,
        setPaymentMethodAsDefault: mockSetPaymentMethodAsDefault,
        onDeletePaymentMethod: mockOnDeletePaymentMethod,
      })

      const copyAction = actions.find((action) => action.startIcon === 'duplicate')

      expect(copyAction).toBeDefined()
      if (!copyAction) return

      copyAction.onAction(paymentMethod)

      expect(copyToClipboard).toHaveBeenCalledWith('pm_copy_001')

      expect(addToast).toHaveBeenCalledWith(
        expect.objectContaining({
          severity: 'info',
        }),
      )
    })
  })

  describe('WHEN executing delete action', () => {
    it('THEN opens delete payment method dialog', () => {
      const paymentMethod = createMockPaymentMethod({ id: 'pm_delete_001' })
      const actions = generatePaymentMethodsActions({
        item: paymentMethod,
        translate: mockTranslate,
        setPaymentMethodAsDefault: mockSetPaymentMethodAsDefault,
        onDeletePaymentMethod: mockOnDeletePaymentMethod,
      })

      const deleteAction = actions.find((action) => action.startIcon === 'trash')

      expect(deleteAction).toBeDefined()
      if (!deleteAction) return

      deleteAction.onAction(paymentMethod)

      expect(mockOnDeletePaymentMethod).toHaveBeenCalledWith(paymentMethod)
    })
  })
})
