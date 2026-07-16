import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { CurrencyEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { type AddOnItem, pricingDrawerDefaultValues } from '../constants'
import PricingDrawerContent from '../PricingDrawerContent'

const mockUsePlansQuery = jest.fn()
const mockUseGetAddOnsForPricingSectionQuery = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  usePlansQuery: (...args: unknown[]) => mockUsePlansQuery(...args),
  useGetAddOnsForPricingSectionQuery: (...args: unknown[]) =>
    mockUseGetAddOnsForPricingSectionQuery(...args),
}))

// drawerStack.ts uses import.meta.hot — mock the entire useDrawer module instead
jest.mock('~/components/drawers/useDrawer', () => ({
  useDrawer: () => ({ open: jest.fn(), close: jest.fn() }),
  useFormDrawer: () => ({ open: jest.fn(), close: jest.fn() }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

// Helper to render with a form wrapper
const renderWithForm = ({
  currency = CurrencyEnum.Usd,
  initialValues,
}: {
  currency?: CurrencyEnum
  initialValues?: { planId?: string; addOnItems?: AddOnItem[] }
} = {}) => {
  // We use a wrapper component that creates the form via useAppForm
  // and passes it to PricingDrawerContent
  const { useAppForm: useAppFormHook } = jest.requireActual('~/hooks/forms/useAppform')

  const Wrapper = () => {
    const form = useAppFormHook({
      defaultValues: {
        ...pricingDrawerDefaultValues,
        planId: initialValues?.planId ?? '',
        addOnItems: initialValues?.addOnItems ?? [],
      },
    })

    return <PricingDrawerContent form={form} currency={currency} />
  }

  return render(<Wrapper />)
}

describe('PricingDrawerContent', () => {
  beforeEach(() => {
    jest.clearAllMocks()

    mockUsePlansQuery.mockReturnValue({
      data: undefined,
      loading: false,
    })

    mockUseGetAddOnsForPricingSectionQuery.mockReturnValue({
      data: undefined,
      loading: false,
    })
  })

  describe('GIVEN the quote type is OneOff', () => {
    describe('WHEN add-ons data is loaded', () => {
      it('THEN should render an add-on button', () => {
        mockUseGetAddOnsForPricingSectionQuery.mockReturnValue({
          data: {
            addOns: {
              collection: [
                { id: 'addon-1', name: 'Setup Fee', code: 'setup_fee' },
                { id: 'addon-2', name: 'Support', code: 'support' },
              ],
            },
          },
          loading: false,
        })

        renderWithForm()

        expect(screen.getByTestId('add-add-on-button')).toBeInTheDocument()
      })
    })

    describe('WHEN an add-on is provided via initial values', () => {
      it('THEN should render the add-on item card with units and unit price fields', () => {
        mockUseGetAddOnsForPricingSectionQuery.mockReturnValue({
          data: { addOns: { collection: [] } },
          loading: false,
        })

        renderWithForm({
          initialValues: {
            addOnItems: [
              {
                localId: 'local-1',
                addOnId: 'addon-1',
                name: 'Setup Fee',
                invoiceDisplayName: '',
                code: 'setup_fee',
                description: '',
                units: '1',
                unitAmountCents: '50',
                totalAmount: '',
                fromDatetime: '2026-05-28T00:00:00.000+02:00',
                toDatetime: '2026-05-28T23:59:59.999+02:00',
              },
            ],
          },
        })

        expect(screen.getByTestId('add-on-item-0')).toBeInTheDocument()
        expect(screen.getByText('Setup Fee')).toBeInTheDocument()
      })
    })

    describe('WHEN the remove button is clicked via popper menu', () => {
      it('THEN should remove the add-on item', async () => {
        mockUseGetAddOnsForPricingSectionQuery.mockReturnValue({
          data: { addOns: { collection: [] } },
          loading: false,
        })

        renderWithForm({
          initialValues: {
            addOnItems: [
              {
                localId: 'local-1',
                addOnId: 'addon-1',
                name: 'Setup Fee',
                invoiceDisplayName: '',
                code: 'setup_fee',
                description: '',
                units: '1',
                unitAmountCents: '50',
                totalAmount: '',
                fromDatetime: '2026-05-28T00:00:00.000+02:00',
                toDatetime: '2026-05-28T23:59:59.999+02:00',
              },
            ],
          },
        })

        expect(screen.getByTestId('add-on-item-0')).toBeInTheDocument()

        // Open the popper menu
        await userEvent.click(screen.getByTestId('add-on-actions-0'))
        // Click the delete button
        await userEvent.click(screen.getByText('text_63aa085d28b8510cd46443ff'))

        expect(screen.queryByTestId('add-on-item-0')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the query configuration', () => {
    it('THEN should not call plans query for one-off quote type', () => {
      mockUseGetAddOnsForPricingSectionQuery.mockReturnValue({
        data: { addOns: { collection: [] } },
        loading: false,
      })

      renderWithForm()

      expect(mockUsePlansQuery).not.toHaveBeenCalled()
    })

    it('THEN should fetch add-ons with correct options for one-off quote type', () => {
      mockUseGetAddOnsForPricingSectionQuery.mockReturnValue({
        data: { addOns: { collection: [] } },
        loading: false,
      })

      renderWithForm()

      expect(mockUseGetAddOnsForPricingSectionQuery).toHaveBeenCalledWith(
        expect.objectContaining({
          variables: { limit: 100 },
          fetchPolicy: 'network-only',
          nextFetchPolicy: 'network-only',
        }),
      )
    })
  })
})
