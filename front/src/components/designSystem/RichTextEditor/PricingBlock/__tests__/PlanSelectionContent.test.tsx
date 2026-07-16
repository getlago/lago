import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import { pricingDrawerDefaultValues } from '../constants'
import PlanSelectionContent from '../PlanSelectionContent'

const mockUsePlansQuery = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  usePlansQuery: (...args: unknown[]) => mockUsePlansQuery(...args),
}))

jest.mock('@tanstack/react-virtual', () => ({
  useVirtualizer: ({ count }: { count: number }) => ({
    getTotalSize: () => count * 56,
    getVirtualItems: () =>
      Array.from({ length: count }, (_, i) => ({
        index: i,
        key: String(i),
        start: i * 56,
        size: 56,
      })),
    scrollToIndex: jest.fn(),
    measureElement: jest.fn(),
  }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const renderWithForm = (initialValues?: { planId?: string }) => {
  const { useAppForm: useAppFormHook } = jest.requireActual('~/hooks/forms/useAppform')

  const Wrapper = () => {
    const form = useAppFormHook({
      defaultValues: {
        ...pricingDrawerDefaultValues,
        planId: initialValues?.planId ?? '',
      },
    })

    return <PlanSelectionContent form={form} />
  }

  return render(<Wrapper />)
}

describe('PlanSelectionContent', () => {
  beforeEach(() => {
    jest.clearAllMocks()

    mockUsePlansQuery.mockReturnValue({
      data: undefined,
      loading: false,
    })
  })

  describe('GIVEN the component is rendered', () => {
    describe('WHEN plans data is loaded', () => {
      it('THEN should render a combobox with the correct name attribute', () => {
        mockUsePlansQuery.mockReturnValue({
          data: {
            plans: {
              collection: [
                { id: 'plan-1', name: 'Basic', code: 'basic' },
                { id: 'plan-2', name: 'Pro', code: 'pro' },
              ],
            },
          },
          loading: false,
        })

        renderWithForm()

        const combobox = screen.getByRole('combobox') as HTMLInputElement

        expect(combobox).toBeInTheDocument()
        expect(combobox.name).toBe('planId')
      })
    })

    describe('WHEN plans are loading', () => {
      it('THEN should render the combobox while loading', () => {
        mockUsePlansQuery.mockReturnValue({
          data: undefined,
          loading: true,
        })

        renderWithForm()

        expect(screen.getByRole('combobox')).toBeInTheDocument()
      })
    })

    it.each([
      { scenario: 'empty collection', data: { plans: { collection: [] } } },
      { scenario: 'undefined data', data: undefined },
    ])('THEN should render the combobox without errors when data is $scenario', ({ data }) => {
      mockUsePlansQuery.mockReturnValue({
        data,
        loading: false,
      })

      renderWithForm()

      expect(screen.getByRole('combobox')).toBeInTheDocument()
    })
  })

  describe('GIVEN the query configuration', () => {
    it('THEN should call usePlansQuery with correct variables and fetch policy', () => {
      mockUsePlansQuery.mockReturnValue({
        data: { plans: { collection: [] } },
        loading: false,
      })

      renderWithForm()

      expect(mockUsePlansQuery).toHaveBeenCalledWith(
        expect.objectContaining({
          variables: { limit: 100 },
          fetchPolicy: 'network-only',
          nextFetchPolicy: 'network-only',
        }),
      )
    })
  })

  describe('GIVEN a plan is pre-selected via initial values', () => {
    it.each([
      {
        planId: 'plan-1',
        expectedValue: 'Basic (basic)',
        plans: [
          { id: 'plan-1', name: 'Basic', code: 'basic' },
          { id: 'plan-2', name: 'Pro', code: 'pro' },
        ],
      },
      {
        planId: 'plan-2',
        expectedValue: 'Pro (pro)',
        plans: [
          { id: 'plan-1', name: 'Basic', code: 'basic' },
          { id: 'plan-2', name: 'Pro', code: 'pro' },
        ],
      },
    ])(
      'THEN should display "$expectedValue" when planId is "$planId"',
      ({ planId, expectedValue, plans }) => {
        mockUsePlansQuery.mockReturnValue({
          data: { plans: { collection: plans } },
          loading: false,
        })

        renderWithForm({ planId })

        const combobox = screen.getByRole('combobox') as HTMLInputElement

        expect(combobox.value).toBe(expectedValue)
      },
    )
  })

  describe('GIVEN no plan is pre-selected', () => {
    describe('WHEN the component is rendered', () => {
      it('THEN should render the combobox with an empty value', () => {
        mockUsePlansQuery.mockReturnValue({
          data: {
            plans: {
              collection: [{ id: 'plan-1', name: 'Basic', code: 'basic' }],
            },
          },
          loading: false,
        })

        renderWithForm()

        const combobox = screen.getByRole('combobox') as HTMLInputElement

        expect(combobox.value).toBe('')
      })
    })

    describe('WHEN a plan is selected from the dropdown', () => {
      it('THEN should update the form value to the selected plan', async () => {
        mockUsePlansQuery.mockReturnValue({
          data: {
            plans: {
              collection: [
                { id: 'plan-1', name: 'Basic', code: 'basic' },
                { id: 'plan-2', name: 'Pro', code: 'pro' },
              ],
            },
          },
          loading: false,
        })

        renderWithForm()

        const combobox = screen.getByRole('combobox') as HTMLInputElement

        await userEvent.type(combobox, 'Pro')

        await waitFor(() => {
          const listboxId = combobox.getAttribute('aria-controls')

          expect(listboxId).toBeTruthy()

          const listbox = document.getElementById(listboxId as string)

          expect(listbox).toBeInTheDocument()
        })

        const listboxId = combobox.getAttribute('aria-controls') as string
        const listbox = document.getElementById(listboxId) as HTMLElement

        await userEvent.click(within(listbox).getByText('Pro'))

        await waitFor(() => {
          expect(combobox.value).toBe('Pro (pro)')
        })
      })
    })
  })
})
