import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { FeeActionsCell } from '~/components/invoices/details/FeeActionsCell'
import {
  FEE_ACTIONS_BUTTON_TEST_ID,
  FEE_ACTIONS_CELL_TEST_ID,
  FEE_COPY_ID_BUTTON_TEST_ID,
  FEE_VIEW_DETAILS_BUTTON_TEST_ID,
} from '~/components/invoices/details/invoiceDetailsTestIds'
import { addToast } from '~/core/apolloClient'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import { FeeForViewFeeDetailsDrawerFragment } from '~/generated/graphql'
import { render } from '~/test-utils'

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

jest.mock('~/core/utils/copyToClipboard', () => ({
  copyToClipboard: jest.fn(),
}))

// The drawer hook pulls in Vite-only modules through `drawerStack`. Stub it
// at the closest seam so we can assert on `open(fee)` without booting NiceModal.
const mockHookOpen = jest.fn()
const mockHookClose = jest.fn()

jest.mock('~/components/invoices/details/ViewFeeDetailsDrawer', () => ({
  useViewFeeDetailsDrawer: () => ({
    open: mockHookOpen,
    close: mockHookClose,
  }),
}))

const baseFee = {
  id: 'fee-123',
  amountCents: 10000,
  amountCurrency: 'USD',
  itemName: 'Test fee',
} as unknown as FeeForViewFeeDetailsDrawerFragment

const renderInTable = (ui: React.ReactNode) =>
  render(
    <table>
      <tbody>
        <tr>{ui}</tr>
      </tbody>
    </table>,
  )

describe('FeeActionsCell', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN a fee', () => {
    describe('WHEN the cell is rendered', () => {
      it('THEN should render the actions cell container', () => {
        renderInTable(<FeeActionsCell fee={baseFee} />)

        expect(screen.getByTestId(FEE_ACTIONS_CELL_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render the dots-menu trigger button', () => {
        renderInTable(<FeeActionsCell fee={baseFee} />)

        expect(screen.getByTestId(FEE_ACTIONS_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should NOT render menu items until the trigger is clicked', () => {
        renderInTable(<FeeActionsCell fee={baseFee} />)

        expect(screen.queryByTestId(FEE_COPY_ID_BUTTON_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(FEE_VIEW_DETAILS_BUTTON_TEST_ID)).not.toBeInTheDocument()
      })
    })

    describe('WHEN user opens the menu', () => {
      it.each([
        ['Copy fee ID', FEE_COPY_ID_BUTTON_TEST_ID],
        ['View fee details', FEE_VIEW_DETAILS_BUTTON_TEST_ID],
      ])('THEN should display the %s action', async (_, testId) => {
        const user = userEvent.setup()

        renderInTable(<FeeActionsCell fee={baseFee} />)

        await user.click(screen.getByTestId(FEE_ACTIONS_BUTTON_TEST_ID))

        expect(await screen.findByTestId(testId)).toBeInTheDocument()
      })
    })

    describe('WHEN user clicks Copy fee ID', () => {
      it('THEN should copy the fee id to the clipboard', async () => {
        const user = userEvent.setup()

        renderInTable(<FeeActionsCell fee={baseFee} />)

        await user.click(screen.getByTestId(FEE_ACTIONS_BUTTON_TEST_ID))
        await user.click(await screen.findByTestId(FEE_COPY_ID_BUTTON_TEST_ID))

        expect(copyToClipboard).toHaveBeenCalledWith('fee-123')
      })

      it('THEN should fire an info toast', async () => {
        const user = userEvent.setup()

        renderInTable(<FeeActionsCell fee={baseFee} />)

        await user.click(screen.getByTestId(FEE_ACTIONS_BUTTON_TEST_ID))
        await user.click(await screen.findByTestId(FEE_COPY_ID_BUTTON_TEST_ID))

        expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'info' }))
      })
    })

    describe('WHEN user clicks View fee details', () => {
      it('THEN should open the drawer via the hook with the fee', async () => {
        const user = userEvent.setup()

        renderInTable(<FeeActionsCell fee={baseFee} />)

        await user.click(screen.getByTestId(FEE_ACTIONS_BUTTON_TEST_ID))
        await user.click(await screen.findByTestId(FEE_VIEW_DETAILS_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(mockHookOpen).toHaveBeenCalledWith(baseFee)
        })
      })

      it('THEN should NOT call open when fee is null', async () => {
        const user = userEvent.setup()

        renderInTable(<FeeActionsCell fee={null} />)

        await user.click(screen.getByTestId(FEE_ACTIONS_BUTTON_TEST_ID))
        await user.click(await screen.findByTestId(FEE_VIEW_DETAILS_BUTTON_TEST_ID))

        expect(mockHookOpen).not.toHaveBeenCalled()
      })
    })

    describe('WHEN user clicks the cell', () => {
      it('THEN should stop propagation so the parent row click does not fire', async () => {
        const user = userEvent.setup()
        const rowClick = jest.fn()

        render(
          <table>
            <tbody>
              <tr onClick={rowClick}>
                <FeeActionsCell fee={baseFee} />
              </tr>
            </tbody>
          </table>,
        )

        await user.click(screen.getByTestId(FEE_ACTIONS_BUTTON_TEST_ID))

        expect(rowClick).not.toHaveBeenCalled()
      })
    })
  })
})
