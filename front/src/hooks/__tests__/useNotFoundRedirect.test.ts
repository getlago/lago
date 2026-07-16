import { ApolloError } from '@apollo/client'
import { captureException } from '@sentry/react'
import { renderHook, waitFor } from '@testing-library/react'

import { addToast } from '~/core/apolloClient'
import { LagoApiError } from '~/generated/graphql'
import { useNotFoundRedirect } from '~/hooks/useNotFoundRedirect'
import { AllTheProviders } from '~/test-utils'

jest.mock('@sentry/react', () => ({
  captureException: jest.fn(),
}))

const mockNavigate = jest.fn()

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useNavigate: () => mockNavigate,
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

const createNotFoundError = () =>
  new ApolloError({
    graphQLErrors: [
      {
        message: 'not found',
        extensions: { code: LagoApiError.NotFound },
      },
    ] as ApolloError['graphQLErrors'],
  })

const createOtherError = () =>
  new ApolloError({
    graphQLErrors: [
      {
        message: 'unauthorized',
        extensions: { code: LagoApiError.Unauthorized },
      },
    ] as ApolloError['graphQLErrors'],
  })

describe('useNotFoundRedirect', () => {
  const customWrapper = ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({ children })

  const defaultArgs = {
    error: undefined as ApolloError | undefined,
    loading: false,
    redirectTo: '/resources',
    translateKey: 'text_some_key',
  }

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN no error occurred', () => {
    describe('WHEN the query finishes loading', () => {
      it('THEN should not navigate or show a toast', () => {
        renderHook(() => useNotFoundRedirect({ ...defaultArgs, loading: false }), {
          wrapper: customWrapper,
        })

        expect(mockNavigate).not.toHaveBeenCalled()
        expect(addToast).not.toHaveBeenCalled()
        expect(captureException).not.toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the query is still loading', () => {
    describe('WHEN a NotFound error is present', () => {
      it('THEN should not navigate or show a toast yet', () => {
        renderHook(
          () =>
            useNotFoundRedirect({
              ...defaultArgs,
              loading: true,
              error: createNotFoundError(),
            }),
          { wrapper: customWrapper },
        )

        expect(mockNavigate).not.toHaveBeenCalled()
        expect(addToast).not.toHaveBeenCalled()
        expect(captureException).not.toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN a NotFound error occurred', () => {
    describe('WHEN loading is complete', () => {
      it('THEN should navigate to the redirect route with replace', async () => {
        renderHook(
          () =>
            useNotFoundRedirect({
              ...defaultArgs,
              error: createNotFoundError(),
            }),
          { wrapper: customWrapper },
        )

        await waitFor(() => {
          expect(mockNavigate).toHaveBeenCalledWith('/resources', { replace: true })
        })
      })

      it('THEN should report the error to Sentry', async () => {
        const notFoundError = createNotFoundError()

        renderHook(
          () =>
            useNotFoundRedirect({
              ...defaultArgs,
              error: notFoundError,
            }),
          { wrapper: customWrapper },
        )

        await waitFor(() => {
          expect(captureException).toHaveBeenCalledWith(notFoundError, {
            tags: {
              errorType: 'NotFoundRedirect',
              fromPath: window.location.pathname,
              redirectTo: '/resources',
            },
          })
        })
      })

      it('THEN should show an info toast with the provided translateKey', async () => {
        renderHook(
          () =>
            useNotFoundRedirect({
              ...defaultArgs,
              error: createNotFoundError(),
            }),
          { wrapper: customWrapper },
        )

        await waitFor(() => {
          expect(addToast).toHaveBeenCalledWith({
            severity: 'info',
            translateKey: 'text_some_key',
          })
        })
      })
    })
  })

  describe('GIVEN a non-NotFound error occurred', () => {
    describe('WHEN loading is complete', () => {
      it('THEN should not navigate or show a toast', () => {
        renderHook(
          () =>
            useNotFoundRedirect({
              ...defaultArgs,
              error: createOtherError(),
            }),
          { wrapper: customWrapper },
        )

        expect(mockNavigate).not.toHaveBeenCalled()
        expect(addToast).not.toHaveBeenCalled()
        expect(captureException).not.toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the redirect route varies', () => {
    describe('WHEN a NotFound error triggers redirect', () => {
      it.each([
        ['/customers', 'text_customer_key'],
        ['/invoices', 'text_invoice_key'],
        ['/plans', 'text_plan_key'],
      ])(
        'THEN should navigate to %s with the correct translateKey',
        async (redirectTo, translateKey) => {
          renderHook(
            () =>
              useNotFoundRedirect({
                error: createNotFoundError(),
                loading: false,
                redirectTo,
                translateKey,
              }),
            { wrapper: customWrapper },
          )

          await waitFor(() => {
            expect(mockNavigate).toHaveBeenCalledWith(redirectTo, { replace: true })
            expect(addToast).toHaveBeenCalledWith({
              severity: 'info',
              translateKey,
            })
          })
        },
      )
    })
  })
})
