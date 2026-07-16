import { act, renderHook } from '@testing-library/react'

import { addToast } from '~/core/apolloClient'
import { CurrencyEnum } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import {
  EDIT_DEFAULT_CURRENCY_FORM_ID,
  useEditDefaultCurrencyDialog,
} from '../EditDefaultCurrencyDialog'

const mockFormDialogOpen = jest.fn()
const mockUpdateBillingEntity = jest.fn()

jest.mock('~/components/dialogs/FormDialog', () => ({
  ...jest.requireActual('~/components/dialogs/FormDialog'),
  useFormDialog: () => ({
    open: mockFormDialogOpen,
    close: jest.fn(),
  }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

jest.mock('~/generated/graphql', () => {
  const actual = jest.requireActual('~/generated/graphql')

  return {
    ...actual,
    useUpdateBillingEntityDefaultCurrencyMutation: (options?: {
      onCompleted?: (data: unknown) => void
    }) => [
      async (variables: unknown) => {
        const result = await mockUpdateBillingEntity(variables)

        if (result?.data) {
          options?.onCompleted?.(result.data)
        }

        return result
      },
    ],
  }
})

const mockBillingEntity = {
  __typename: 'BillingEntity' as const,
  id: 'billing-entity-1',
  defaultCurrency: CurrencyEnum.Eur,
}

describe('useEditDefaultCurrencyDialog', () => {
  const customWrapper = ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({ children })

  beforeEach(() => {
    jest.clearAllMocks()
    mockFormDialogOpen.mockResolvedValue({ reason: 'close' })
  })

  describe('GIVEN the hook is initialized', () => {
    describe('WHEN rendered', () => {
      it('THEN should return openEditDefaultCurrencyDialog function', () => {
        const { result } = renderHook(() => useEditDefaultCurrencyDialog(), {
          wrapper: customWrapper,
        })

        expect(typeof result.current.openEditDefaultCurrencyDialog).toBe('function')
      })
    })
  })

  describe('GIVEN openEditDefaultCurrencyDialog is called', () => {
    describe('WHEN opening the dialog', () => {
      it('THEN should call formDialog.open once', () => {
        const { result } = renderHook(() => useEditDefaultCurrencyDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditDefaultCurrencyDialog({ billingEntity: mockBillingEntity })
        })

        expect(mockFormDialogOpen).toHaveBeenCalledTimes(1)
      })

      it('THEN should include closeOnError false', () => {
        const { result } = renderHook(() => useEditDefaultCurrencyDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditDefaultCurrencyDialog({ billingEntity: mockBillingEntity })
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs.closeOnError).toBe(false)
      })

      it('THEN should pass cancelOrCloseText as cancel', () => {
        const { result } = renderHook(() => useEditDefaultCurrencyDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditDefaultCurrencyDialog({ billingEntity: mockBillingEntity })
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs.cancelOrCloseText).toBe('cancel')
      })

      it.each([
        ['title', 'string'],
        ['description', 'string'],
        ['children', 'object'],
        ['mainAction', 'object'],
      ])('THEN should include %s', (prop, expectedType) => {
        const { result } = renderHook(() => useEditDefaultCurrencyDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditDefaultCurrencyDialog({ billingEntity: mockBillingEntity })
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs[prop]).toBeDefined()
        expect(typeof callArgs[prop]).toBe(expectedType)
      })

      it('THEN should include form with id and submit function', () => {
        const { result } = renderHook(() => useEditDefaultCurrencyDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditDefaultCurrencyDialog({ billingEntity: mockBillingEntity })
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs.form).toBeDefined()
        expect(callArgs.form.id).toBe(EDIT_DEFAULT_CURRENCY_FORM_ID)
        expect(typeof callArgs.form.submit).toBe('function')
      })
    })
  })

  describe('GIVEN the form is submitted', () => {
    describe('WHEN a currency is provided', () => {
      it('THEN should call the mutation with that currency and billing entity id', async () => {
        mockUpdateBillingEntity.mockResolvedValue({
          data: {
            updateBillingEntity: {
              id: 'billing-entity-1',
              defaultCurrency: CurrencyEnum.Eur,
              __typename: 'BillingEntity',
            },
          },
          errors: undefined,
        })
        mockFormDialogOpen.mockImplementation(async (config) => {
          await config.form.submit()
          return { reason: 'success' }
        })

        const { result } = renderHook(() => useEditDefaultCurrencyDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditDefaultCurrencyDialog({ billingEntity: mockBillingEntity })
        })

        expect(mockUpdateBillingEntity).toHaveBeenCalledWith({
          variables: {
            input: { id: 'billing-entity-1', defaultCurrency: CurrencyEnum.Eur },
          },
        })
      })
    })

    describe('WHEN the mutation succeeds', () => {
      it('THEN should show success toast', async () => {
        mockUpdateBillingEntity.mockResolvedValue({
          data: {
            updateBillingEntity: {
              id: 'billing-entity-1',
              defaultCurrency: CurrencyEnum.Eur,
              __typename: 'BillingEntity',
            },
          },
          errors: undefined,
        })
        mockFormDialogOpen.mockImplementation(async (config) => {
          await config.form.submit()
          return { reason: 'success' }
        })

        const { result } = renderHook(() => useEditDefaultCurrencyDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditDefaultCurrencyDialog({ billingEntity: mockBillingEntity })
        })

        expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'success' }))
      })
    })

    describe('WHEN the mutation returns no data', () => {
      it('THEN handleSubmit should throw Submit failed', async () => {
        mockUpdateBillingEntity.mockResolvedValue({ data: null, errors: undefined })

        let submitError: unknown = null

        mockFormDialogOpen.mockImplementation(async (config) => {
          try {
            await config.form.submit()
          } catch (err) {
            submitError = err
          }

          return { reason: 'close' }
        })

        const { result } = renderHook(() => useEditDefaultCurrencyDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditDefaultCurrencyDialog({ billingEntity: mockBillingEntity })
        })

        expect(submitError).toBeInstanceOf(Error)
        expect((submitError as Error).message).toBe('Submit failed')
      })
    })
  })

  describe('GIVEN the dialog resolves with close', () => {
    describe('WHEN dialog is cancelled before submit', () => {
      it('THEN should not call the mutation', async () => {
        mockFormDialogOpen.mockResolvedValue({ reason: 'close' })

        const { result } = renderHook(() => useEditDefaultCurrencyDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditDefaultCurrencyDialog({ billingEntity: mockBillingEntity })
        })

        expect(mockUpdateBillingEntity).not.toHaveBeenCalled()
      })

      it('THEN should not show a toast', async () => {
        mockFormDialogOpen.mockResolvedValue({ reason: 'close' })

        const { result } = renderHook(() => useEditDefaultCurrencyDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditDefaultCurrencyDialog({ billingEntity: mockBillingEntity })
        })

        expect(addToast).not.toHaveBeenCalled()
      })
    })
  })
})
