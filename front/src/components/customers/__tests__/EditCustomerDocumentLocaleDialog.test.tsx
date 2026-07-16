import { act, renderHook } from '@testing-library/react'

import { addToast } from '~/core/apolloClient'
import { EditCustomerDocumentLocaleFragment } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import {
  EDIT_CUSTOMER_DOCUMENT_LOCALE_FORM_ID,
  useEditCustomerDocumentLocaleDialog,
} from '../EditCustomerDocumentLocaleDialog'

const mockFormDialogOpen = jest.fn()
const mockUpdateDocumentLocale = jest.fn()

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
    useUpdateCustomerDocumentLocaleMutation: (options?: {
      onCompleted?: (data: unknown) => void
    }) => [
      async (variables: unknown) => {
        const result = await mockUpdateDocumentLocale(variables)

        if (result?.data) {
          options?.onCompleted?.(result.data)
        }

        return result
      },
    ],
  }
})

const buildCustomer = (
  overrides: Partial<EditCustomerDocumentLocaleFragment> = {},
): EditCustomerDocumentLocaleFragment => ({
  __typename: 'Customer',
  id: 'customer-1',
  name: 'Test Customer',
  displayName: 'Test Customer',
  externalId: 'external-1',
  billingConfiguration: {
    __typename: 'CustomerBillingConfiguration',
    id: 'billing-config-1',
    documentLocale: 'en',
  },
  ...overrides,
})

const buildSuccessResult = () => ({
  data: {
    updateCustomer: {
      __typename: 'Customer',
      id: 'customer-1',
      billingConfiguration: {
        __typename: 'CustomerBillingConfiguration',
        id: 'billing-config-1',
        documentLocale: 'en',
      },
    },
  },
  errors: undefined,
})

describe('useEditCustomerDocumentLocaleDialog', () => {
  const customWrapper = ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({ children })

  beforeEach(() => {
    jest.clearAllMocks()
    mockFormDialogOpen.mockResolvedValue({ reason: 'close' })
  })

  describe('GIVEN the hook is initialized', () => {
    describe('WHEN rendered', () => {
      it('THEN should return openEditCustomerDocumentLocaleDialog function', () => {
        const { result } = renderHook(() => useEditCustomerDocumentLocaleDialog(), {
          wrapper: customWrapper,
        })

        expect(typeof result.current.openEditCustomerDocumentLocaleDialog).toBe('function')
      })
    })
  })

  describe('GIVEN openEditCustomerDocumentLocaleDialog is called', () => {
    describe('WHEN opening the dialog', () => {
      it('THEN should call formDialog.open once', () => {
        const { result } = renderHook(() => useEditCustomerDocumentLocaleDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditCustomerDocumentLocaleDialog(buildCustomer())
        })

        expect(mockFormDialogOpen).toHaveBeenCalledTimes(1)
      })

      it('THEN should include closeOnError false', () => {
        const { result } = renderHook(() => useEditCustomerDocumentLocaleDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditCustomerDocumentLocaleDialog(buildCustomer())
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs.closeOnError).toBe(false)
      })

      it.each([
        ['title', 'string'],
        ['description', 'object'],
        ['children', 'object'],
        ['mainAction', 'object'],
      ])('THEN should include %s', (prop, expectedType) => {
        const { result } = renderHook(() => useEditCustomerDocumentLocaleDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditCustomerDocumentLocaleDialog(buildCustomer())
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs[prop]).toBeDefined()
        expect(typeof callArgs[prop]).toBe(expectedType)
      })

      it('THEN should include form with the expected id and a submit function', () => {
        const { result } = renderHook(() => useEditCustomerDocumentLocaleDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditCustomerDocumentLocaleDialog(buildCustomer())
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs.form).toBeDefined()
        expect(callArgs.form.id).toBe(EDIT_CUSTOMER_DOCUMENT_LOCALE_FORM_ID)
        expect(typeof callArgs.form.submit).toBe('function')
      })
    })
  })

  describe('GIVEN the form is submitted', () => {
    describe('WHEN a document locale is provided', () => {
      it('THEN should call the mutation with id, billingConfiguration and required customer fields', async () => {
        mockUpdateDocumentLocale.mockResolvedValue(buildSuccessResult())
        mockFormDialogOpen.mockImplementation(async (config) => {
          await config.form.submit()
          return { reason: 'success' }
        })

        const { result } = renderHook(() => useEditCustomerDocumentLocaleDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditCustomerDocumentLocaleDialog(buildCustomer())
        })

        expect(mockUpdateDocumentLocale).toHaveBeenCalledWith({
          variables: {
            input: {
              id: 'customer-1',
              billingConfiguration: { documentLocale: 'en' },
              externalId: 'external-1',
              name: 'Test Customer',
            },
          },
        })
      })
    })

    describe('WHEN the mutation succeeds', () => {
      it('THEN should show a success toast', async () => {
        mockUpdateDocumentLocale.mockResolvedValue(buildSuccessResult())
        mockFormDialogOpen.mockImplementation(async (config) => {
          await config.form.submit()
          return { reason: 'success' }
        })

        const { result } = renderHook(() => useEditCustomerDocumentLocaleDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditCustomerDocumentLocaleDialog(buildCustomer())
        })

        expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'success' }))
      })
    })

    describe('WHEN the mutation returns no data', () => {
      it('THEN handleSubmit should throw Submit failed', async () => {
        mockUpdateDocumentLocale.mockResolvedValue({ data: null, errors: undefined })

        let submitError: unknown = null

        mockFormDialogOpen.mockImplementation(async (config) => {
          try {
            await config.form.submit()
          } catch (err) {
            submitError = err
          }

          return { reason: 'close' }
        })

        const { result } = renderHook(() => useEditCustomerDocumentLocaleDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditCustomerDocumentLocaleDialog(buildCustomer())
        })

        expect(submitError).toBeInstanceOf(Error)
        expect((submitError as Error).message).toBe('Submit failed')
      })
    })
  })

  describe('GIVEN the dialog resolves with close', () => {
    describe('WHEN the dialog is cancelled before submit', () => {
      it('THEN should not call the mutation', async () => {
        mockFormDialogOpen.mockResolvedValue({ reason: 'close' })

        const { result } = renderHook(() => useEditCustomerDocumentLocaleDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditCustomerDocumentLocaleDialog(buildCustomer())
        })

        expect(mockUpdateDocumentLocale).not.toHaveBeenCalled()
      })

      it('THEN should not show a toast', async () => {
        mockFormDialogOpen.mockResolvedValue({ reason: 'close' })

        const { result } = renderHook(() => useEditCustomerDocumentLocaleDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditCustomerDocumentLocaleDialog(buildCustomer())
        })

        expect(addToast).not.toHaveBeenCalled()
      })
    })
  })
})
