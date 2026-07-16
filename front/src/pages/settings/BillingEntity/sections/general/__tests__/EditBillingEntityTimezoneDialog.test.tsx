import { act, renderHook } from '@testing-library/react'
import { Settings } from 'luxon'

import { addToast } from '~/core/apolloClient'
import { TimezoneEnum } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import {
  EDIT_BILLING_ENTITY_TIMEZONE_FORM_ID,
  useEditBillingEntityTimezoneDialog,
} from '../EditBillingEntityTimezoneDialog'

const mockFormDialogOpen = jest.fn()
const mockUpdate = jest.fn()

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
    useUpdateBillingEntityTimezoneMutation: (options?: {
      onCompleted?: (data: unknown) => void
    }) => [
      async (variables: unknown) => {
        const result = await mockUpdate(variables)

        if (result?.data) {
          options?.onCompleted?.(result.data)
        }

        return result
      },
    ],
  }
})

describe('useEditBillingEntityTimezoneDialog', () => {
  const originalDefaultZone = Settings.defaultZone
  const customWrapper = ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({ children })

  beforeEach(() => {
    jest.clearAllMocks()
    mockFormDialogOpen.mockResolvedValue({ reason: 'close' })
  })

  afterEach(() => {
    Settings.defaultZone = originalDefaultZone
  })

  describe('GIVEN the hook is initialized', () => {
    describe('WHEN rendered', () => {
      it('THEN should return openEditBillingEntityTimezoneDialog function', () => {
        const { result } = renderHook(() => useEditBillingEntityTimezoneDialog(), {
          wrapper: customWrapper,
        })

        expect(typeof result.current.openEditBillingEntityTimezoneDialog).toBe('function')
      })
    })
  })

  describe('GIVEN openEditBillingEntityTimezoneDialog is called', () => {
    describe('WHEN opening the dialog', () => {
      it('THEN should call formDialog.open once', () => {
        const { result } = renderHook(() => useEditBillingEntityTimezoneDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditBillingEntityTimezoneDialog({
            id: 'be-1',
            timezone: TimezoneEnum.TzEuropeParis,
          })
        })

        expect(mockFormDialogOpen).toHaveBeenCalledTimes(1)
      })

      it('THEN should include closeOnError false', () => {
        const { result } = renderHook(() => useEditBillingEntityTimezoneDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditBillingEntityTimezoneDialog({
            id: 'be-1',
            timezone: TimezoneEnum.TzEuropeParis,
          })
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs.closeOnError).toBe(false)
      })

      it('THEN should pass cancelOrCloseText as cancel', () => {
        const { result } = renderHook(() => useEditBillingEntityTimezoneDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditBillingEntityTimezoneDialog({
            id: 'be-1',
            timezone: TimezoneEnum.TzEuropeParis,
          })
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
        const { result } = renderHook(() => useEditBillingEntityTimezoneDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditBillingEntityTimezoneDialog({
            id: 'be-1',
            timezone: TimezoneEnum.TzEuropeParis,
          })
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs[prop]).toBeDefined()
        expect(typeof callArgs[prop]).toBe(expectedType)
      })

      it('THEN should include form with id and submit function', () => {
        const { result } = renderHook(() => useEditBillingEntityTimezoneDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditBillingEntityTimezoneDialog({
            id: 'be-1',
            timezone: TimezoneEnum.TzEuropeParis,
          })
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs.form).toBeDefined()
        expect(callArgs.form.id).toBe(EDIT_BILLING_ENTITY_TIMEZONE_FORM_ID)
        expect(typeof callArgs.form.submit).toBe('function')
      })
    })
  })

  describe('GIVEN the form is submitted', () => {
    describe('WHEN a timezone is provided', () => {
      it('THEN should call the mutation with that timezone and id', async () => {
        mockUpdate.mockResolvedValue({
          data: {
            updateBillingEntity: { id: 'be-1', timezone: TimezoneEnum.TzEuropeParis },
          },
          errors: undefined,
        })
        mockFormDialogOpen.mockImplementation(async (config) => {
          await config.form.submit()
          return { reason: 'success' }
        })

        const { result } = renderHook(() => useEditBillingEntityTimezoneDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditBillingEntityTimezoneDialog({
            id: 'be-1',
            timezone: TimezoneEnum.TzEuropeParis,
          })
        })

        expect(mockUpdate).toHaveBeenCalledWith({
          variables: {
            input: { id: 'be-1', timezone: TimezoneEnum.TzEuropeParis },
          },
        })
      })
    })

    describe('WHEN no timezone is provided', () => {
      it('THEN should fall back to TzUtc', async () => {
        mockUpdate.mockResolvedValue({
          data: { updateBillingEntity: { id: 'be-1', timezone: TimezoneEnum.TzUtc } },
          errors: undefined,
        })
        mockFormDialogOpen.mockImplementation(async (config) => {
          await config.form.submit()
          return { reason: 'success' }
        })

        const { result } = renderHook(() => useEditBillingEntityTimezoneDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditBillingEntityTimezoneDialog({
            id: 'be-1',
            timezone: null,
          })
        })

        expect(mockUpdate).toHaveBeenCalledWith({
          variables: {
            input: { id: 'be-1', timezone: TimezoneEnum.TzUtc },
          },
        })
      })
    })

    describe('WHEN the mutation succeeds', () => {
      it('THEN should show success toast', async () => {
        mockUpdate.mockResolvedValue({
          data: {
            updateBillingEntity: { id: 'be-1', timezone: TimezoneEnum.TzEuropeParis },
          },
          errors: undefined,
        })
        mockFormDialogOpen.mockImplementation(async (config) => {
          await config.form.submit()
          return { reason: 'success' }
        })

        const { result } = renderHook(() => useEditBillingEntityTimezoneDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditBillingEntityTimezoneDialog({
            id: 'be-1',
            timezone: TimezoneEnum.TzEuropeParis,
          })
        })

        expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'success' }))
      })
    })

    describe('WHEN the mutation returns no data', () => {
      it('THEN handleSubmit should throw Submit failed', async () => {
        mockUpdate.mockResolvedValue({ data: null, errors: undefined })

        let submitError: unknown = null

        mockFormDialogOpen.mockImplementation(async (config) => {
          try {
            await config.form.submit()
          } catch (err) {
            submitError = err
          }

          return { reason: 'close' }
        })

        const { result } = renderHook(() => useEditBillingEntityTimezoneDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditBillingEntityTimezoneDialog({
            id: 'be-1',
            timezone: TimezoneEnum.TzEuropeParis,
          })
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

        const { result } = renderHook(() => useEditBillingEntityTimezoneDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditBillingEntityTimezoneDialog({
            id: 'be-1',
            timezone: TimezoneEnum.TzEuropeParis,
          })
        })

        expect(mockUpdate).not.toHaveBeenCalled()
      })

      it('THEN should not show a toast', async () => {
        mockFormDialogOpen.mockResolvedValue({ reason: 'close' })

        const { result } = renderHook(() => useEditBillingEntityTimezoneDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditBillingEntityTimezoneDialog({
            id: 'be-1',
            timezone: TimezoneEnum.TzEuropeParis,
          })
        })

        expect(addToast).not.toHaveBeenCalled()
      })
    })
  })
})
