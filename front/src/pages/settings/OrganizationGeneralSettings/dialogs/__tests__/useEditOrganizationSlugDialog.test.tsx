import { act, renderHook } from '@testing-library/react'

import { addToast } from '~/core/apolloClient'
import { AllTheProviders } from '~/test-utils'

import { useEditOrganizationSlugDialog } from '../useEditOrganizationSlugDialog'

const mockFormDialogOpen = jest.fn()
const mockNavigate = jest.fn()
const mockUpdateOrganizationSlug = jest.fn()
const mockRewriteSlugInLocationHistory = jest.fn()

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

jest.mock('~/core/router', () => ({
  ...jest.requireActual('~/core/router'),
  GENERAL_SETTINGS_ROUTE: '/settings/general',
  useNavigate: () => mockNavigate,
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

jest.mock('~/core/apolloClient/reactiveVars', () => ({
  ...jest.requireActual('~/core/apolloClient/reactiveVars'),
  rewriteSlugInLocationHistory: (...args: unknown[]) => mockRewriteSlugInLocationHistory(...args),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useUpdateOrganizationSlugMutation: () => [mockUpdateOrganizationSlug],
}))

describe('useEditOrganizationSlugDialog', () => {
  const customWrapper = ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({ children })

  beforeEach(() => {
    jest.clearAllMocks()
    mockFormDialogOpen.mockResolvedValue({ reason: 'close' })
  })

  describe('GIVEN the hook is initialized', () => {
    describe('WHEN rendered', () => {
      it('THEN should return openEditOrganizationSlugDialog function', () => {
        const { result } = renderHook(() => useEditOrganizationSlugDialog(), {
          wrapper: customWrapper,
        })

        expect(typeof result.current.openEditOrganizationSlugDialog).toBe('function')
      })
    })
  })

  describe('GIVEN openEditOrganizationSlugDialog is called', () => {
    describe('WHEN opening the dialog', () => {
      it('THEN should call formDialog.open', () => {
        const { result } = renderHook(() => useEditOrganizationSlugDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditOrganizationSlugDialog({ currentSlug: 'acme' })
        })

        expect(mockFormDialogOpen).toHaveBeenCalledTimes(1)
      })

      it('THEN should include closeOnError false', () => {
        const { result } = renderHook(() => useEditOrganizationSlugDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditOrganizationSlugDialog({ currentSlug: 'acme' })
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs.closeOnError).toBe(false)
      })

      it.each([
        ['title', 'string'],
        ['description', 'string'],
        ['children', 'object'],
        ['mainAction', 'object'],
      ])('THEN should include %s', (prop, expectedType) => {
        const { result } = renderHook(() => useEditOrganizationSlugDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditOrganizationSlugDialog({ currentSlug: 'acme' })
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs[prop]).toBeDefined()
        expect(typeof callArgs[prop]).toBe(expectedType)
      })

      it('THEN should include form with id and submit function', () => {
        const { result } = renderHook(() => useEditOrganizationSlugDialog(), {
          wrapper: customWrapper,
        })

        act(() => {
          result.current.openEditOrganizationSlugDialog({ currentSlug: 'acme' })
        })

        const callArgs = mockFormDialogOpen.mock.calls[0][0]

        expect(callArgs.form).toBeDefined()
        expect(callArgs.form.id).toBe('form-edit-organization-slug')
        expect(typeof callArgs.form.submit).toBe('function')
      })
    })
  })

  describe('GIVEN the dialog resolves with success', () => {
    describe('WHEN mutation succeeds and dialog resolves', () => {
      it('THEN should rewrite slug in location history', async () => {
        mockUpdateOrganizationSlug.mockResolvedValue({
          data: { updateOrganization: { id: 'org-1', slug: 'new-slug' } },
          errors: undefined,
        })

        mockFormDialogOpen.mockImplementation(async (config) => {
          await config.form.submit()
          return { reason: 'success' }
        })

        const { result } = renderHook(() => useEditOrganizationSlugDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditOrganizationSlugDialog({ currentSlug: 'acme' })
        })

        expect(mockRewriteSlugInLocationHistory).toHaveBeenCalledWith('acme', 'new-slug')
      })

      it('THEN should navigate to the new slug settings route', async () => {
        mockUpdateOrganizationSlug.mockResolvedValue({
          data: { updateOrganization: { id: 'org-1', slug: 'new-slug' } },
          errors: undefined,
        })

        mockFormDialogOpen.mockImplementation(async (config) => {
          await config.form.submit()
          return { reason: 'success' }
        })

        const { result } = renderHook(() => useEditOrganizationSlugDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditOrganizationSlugDialog({ currentSlug: 'acme' })
        })

        expect(mockNavigate).toHaveBeenCalledWith('/new-slug/settings/general', {
          skipSlugPrepend: true,
        })
      })

      it('THEN should show success toast', async () => {
        mockUpdateOrganizationSlug.mockResolvedValue({
          data: { updateOrganization: { id: 'org-1', slug: 'new-slug' } },
          errors: undefined,
        })

        mockFormDialogOpen.mockImplementation(async (config) => {
          await config.form.submit()
          return { reason: 'success' }
        })

        const { result } = renderHook(() => useEditOrganizationSlugDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditOrganizationSlugDialog({ currentSlug: 'acme' })
        })

        expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'success' }))
      })
    })
  })

  describe('GIVEN the dialog resolves without success', () => {
    describe('WHEN dialog is closed/cancelled', () => {
      it('THEN should not navigate', async () => {
        mockFormDialogOpen.mockResolvedValue({ reason: 'close' })

        const { result } = renderHook(() => useEditOrganizationSlugDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditOrganizationSlugDialog({ currentSlug: 'acme' })
        })

        expect(mockNavigate).not.toHaveBeenCalled()
      })

      it('THEN should not show toast', async () => {
        mockFormDialogOpen.mockResolvedValue({ reason: 'close' })

        const { result } = renderHook(() => useEditOrganizationSlugDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditOrganizationSlugDialog({ currentSlug: 'acme' })
        })

        expect(addToast).not.toHaveBeenCalled()
      })

      it('THEN should not rewrite location history', async () => {
        mockFormDialogOpen.mockResolvedValue({ reason: 'close' })

        const { result } = renderHook(() => useEditOrganizationSlugDialog(), {
          wrapper: customWrapper,
        })

        await act(async () => {
          result.current.openEditOrganizationSlugDialog({ currentSlug: 'acme' })
        })

        expect(mockRewriteSlugInLocationHistory).not.toHaveBeenCalled()
      })
    })
  })
})
