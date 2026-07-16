import { act, renderHook } from '@testing-library/react'
import { ReactNode } from 'react'

import { addToast } from '~/core/apolloClient'
import { AllTheProviders } from '~/test-utils'

import { useUpdateQuote } from '../useUpdateQuote'

const mockUpdateQuoteVersion = jest.fn()
const mockUpdateQuote = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useUpdateQuoteVersionMutation: () => [mockUpdateQuoteVersion, { loading: false }],
  useUpdateQuoteMutation: () => [mockUpdateQuote, { loading: false }],
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const wrapper = ({ children }: { children: ReactNode }) => (
  <AllTheProviders>{children}</AllTheProviders>
)

describe('useUpdateQuote', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the hook is called', () => {
    describe('WHEN it returns', () => {
      it('THEN should return updateQuoteVersion, updateQuote, isUpdatingQuoteVersion, and isUpdatingQuote', () => {
        const { result } = renderHook(() => useUpdateQuote(), { wrapper })

        expect(typeof result.current.updateQuoteVersion).toBe('function')
        expect(typeof result.current.updateQuote).toBe('function')
        expect(result.current.isUpdatingQuoteVersion).toBe(false)
        expect(result.current.isUpdatingQuote).toBe(false)
      })
    })
  })

  describe('GIVEN updateQuoteVersion is called', () => {
    describe('WHEN called with displayToast=true and mutation succeeds', () => {
      it('THEN should call the mutation with correct variables AND show a success toast', async () => {
        mockUpdateQuoteVersion.mockResolvedValueOnce({
          data: { updateQuoteVersion: { id: 'version-123' } },
        })

        const { result } = renderHook(() => useUpdateQuote(), { wrapper })

        await act(async () => {
          await result.current.updateQuoteVersion(
            { id: 'version-123', name: 'Updated Name' } as never,
            true,
          )
        })

        expect(mockUpdateQuoteVersion).toHaveBeenCalledWith({
          variables: { input: { id: 'version-123', name: 'Updated Name' } },
        })
        expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'success' }))
      })
    })

    describe('WHEN called with displayToast=false and mutation succeeds', () => {
      it('THEN should call the mutation but NOT show a toast', async () => {
        mockUpdateQuoteVersion.mockResolvedValueOnce({
          data: { updateQuoteVersion: { id: 'version-456' } },
        })

        const { result } = renderHook(() => useUpdateQuote(), { wrapper })

        await act(async () => {
          await result.current.updateQuoteVersion({ id: 'version-456' } as never, false)
        })

        expect(mockUpdateQuoteVersion).toHaveBeenCalledWith({
          variables: { input: { id: 'version-456' } },
        })
        expect(addToast).not.toHaveBeenCalled()
      })
    })

    describe('WHEN mutation returns null data', () => {
      it('THEN should NOT show a toast even with displayToast=true', async () => {
        mockUpdateQuoteVersion.mockResolvedValueOnce({
          data: { updateQuoteVersion: null },
        })

        const { result } = renderHook(() => useUpdateQuote(), { wrapper })

        await act(async () => {
          await result.current.updateQuoteVersion({ id: 'version-789' } as never, true)
        })

        expect(mockUpdateQuoteVersion).toHaveBeenCalled()
        expect(addToast).not.toHaveBeenCalled()
      })
    })

    describe('WHEN called with default displayToast parameter', () => {
      it('THEN should show a success toast on success since default is true', async () => {
        mockUpdateQuoteVersion.mockResolvedValueOnce({
          data: { updateQuoteVersion: { id: 'version-default' } },
        })

        const { result } = renderHook(() => useUpdateQuote(), { wrapper })

        await act(async () => {
          await result.current.updateQuoteVersion({ id: 'version-default' } as never)
        })

        expect(mockUpdateQuoteVersion).toHaveBeenCalledWith({
          variables: { input: { id: 'version-default' } },
        })
        expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'success' }))
      })
    })
  })

  describe('GIVEN updateQuoteVersion is called with onUpdateFinished and onUpdateError callbacks', () => {
    describe('WHEN mutation succeeds', () => {
      it('THEN should call onUpdateFinished and NOT onUpdateError', async () => {
        const onUpdateFinished = jest.fn()
        const onUpdateError = jest.fn()

        mockUpdateQuoteVersion.mockResolvedValueOnce({
          data: { updateQuoteVersion: { id: 'version-success' } },
        })

        const { result } = renderHook(() => useUpdateQuote({ onUpdateFinished, onUpdateError }), {
          wrapper,
        })

        await act(async () => {
          await result.current.updateQuoteVersion({ id: 'version-success' } as never, false)
        })

        expect(onUpdateFinished).toHaveBeenCalledTimes(1)
        expect(onUpdateError).not.toHaveBeenCalled()
      })
    })

    describe('WHEN mutation returns null data', () => {
      it('THEN should call onUpdateError and NOT onUpdateFinished', async () => {
        const onUpdateFinished = jest.fn()
        const onUpdateError = jest.fn()

        mockUpdateQuoteVersion.mockResolvedValueOnce({
          data: { updateQuoteVersion: null },
        })

        const { result } = renderHook(() => useUpdateQuote({ onUpdateFinished, onUpdateError }), {
          wrapper,
        })

        await act(async () => {
          await result.current.updateQuoteVersion({ id: 'version-fail' } as never, true)
        })

        expect(onUpdateError).toHaveBeenCalledTimes(1)
        expect(onUpdateFinished).not.toHaveBeenCalled()
        expect(addToast).not.toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN updateQuote is called', () => {
    describe('WHEN called with an input', () => {
      it('THEN should call the mutation with correct variables and return the result', async () => {
        const mockResult = {
          data: {
            updateQuote: {
              id: 'quote-123',
              currentVersion: { id: 'version-1', version: 1, status: 'DRAFT' },
            },
          },
        }

        mockUpdateQuote.mockResolvedValueOnce(mockResult)

        const { result } = renderHook(() => useUpdateQuote(), { wrapper })

        let updateResult: unknown

        await act(async () => {
          updateResult = await result.current.updateQuote({ id: 'quote-123' } as never)
        })

        expect(mockUpdateQuote).toHaveBeenCalledWith({
          variables: { input: { id: 'quote-123' } },
        })
        expect(updateResult).toEqual(mockResult)
      })
    })
  })
})
