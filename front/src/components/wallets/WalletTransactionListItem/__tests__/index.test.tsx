import { act, cleanup, fireEvent, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { DateTime } from 'luxon'

import {
  TRANSACTION_PRIORITY_DATA_TEST,
  TRANSACTION_REMAINING_CREDITS_DATA_TEST,
} from '~/components/wallets/utils/dataTestConstants'
import {
  WalletTransactionListItem,
  WalletTransactionListItemProps,
} from '~/components/wallets/WalletTransactionListItem'
import { addToast } from '~/core/apolloClient'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import {
  GetOrganizationInfosDocument,
  TimezoneEnum,
  WalletTransactionSourceEnum,
  WalletTransactionStatusEnum,
  WalletTransactionTransactionStatusEnum,
  WalletTransactionTransactionTypeEnum,
} from '~/generated/graphql'
import { render } from '~/test-utils'

const CREDITS = '10'

const AMOUNT = '100'

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({
    isPremium: true,
    loading: false,
    currentUser: {
      id: '1',
      email: 'currentUser@mail.com',
      premium: true,
    },
  }),
}))

jest.mock('~/core/utils/copyToClipboard', () => ({
  copyToClipboard: jest.fn(),
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

async function prepare(
  overriddenTransaction?: Partial<WalletTransactionListItemProps['transaction']>,
  isRealTimeTransaction?: boolean,
  onClick?: () => void,
) {
  const mocks = [
    {
      request: {
        query: GetOrganizationInfosDocument,
      },
      result: {
        data: {
          organization: {
            id: '1234',
            name: 'Organization Name',
          },
        },
      },
    },
  ]

  const transaction = {
    id: '1',
    status: WalletTransactionStatusEnum.Settled,
    transactionStatus: WalletTransactionTransactionStatusEnum.Purchased,
    transactionType: WalletTransactionTransactionTypeEnum.Inbound,
    amount: AMOUNT,
    creditAmount: CREDITS,
    settledAt: DateTime.local(2022, 2, 2).toISO(),
    createdAt: DateTime.local(2022, 1, 1).toISO(),
    source: WalletTransactionSourceEnum.Manual,
    ...overriddenTransaction,
  }

  await act(() =>
    render(
      <WalletTransactionListItem
        customerTimezone={TimezoneEnum.TzEuropeParis}
        isRealTimeTransaction={isRealTimeTransaction ?? false}
        isWalletActive={true}
        transaction={transaction}
        onClick={onClick}
      />,
      {
        mocks,
      },
    ),
  )
}

describe('WalletTransactionListItem', () => {
  afterEach(cleanup)

  it('should render purchased item with pending status', async () => {
    await prepare({
      status: WalletTransactionStatusEnum.Pending,
      transactionType: WalletTransactionTransactionTypeEnum.Inbound,
    })

    expect(screen.getByTitle('sync/xsmall')).toBeInTheDocument()
    expect(screen.getByTestId('transaction-label')).toBeInTheDocument()
    expect(screen.getByTestId('credits')).toHaveTextContent(`+${CREDITS}`)
    expect(screen.getAllByTestId('amount')[0]).toHaveTextContent(AMOUNT)
  })

  it('should render invoiced item with pending status', async () => {
    await prepare({
      status: WalletTransactionStatusEnum.Pending,
      transactionType: WalletTransactionTransactionTypeEnum.Outbound,
    })

    expect(screen.getByTitle('sync/xsmall')).toBeInTheDocument()
    expect(screen.getByTestId('transaction-label')).toBeInTheDocument()
    expect(screen.getByTestId('credits')).toHaveTextContent(`-${CREDITS}`)
    expect(screen.getAllByTestId('amount')[0]).toHaveTextContent(AMOUNT)
  })

  it('should render purchased item with paid status', async () => {
    await prepare({
      status: WalletTransactionStatusEnum.Settled,
      transactionType: WalletTransactionTransactionTypeEnum.Inbound,
    })

    expect(screen.getByTitle('plus/medium')).toBeInTheDocument()
    expect(screen.queryByTestId('caption-pending')).not.toBeInTheDocument()
  })

  it('should render invoiced item with paid status', async () => {
    await prepare({
      status: WalletTransactionStatusEnum.Settled,
      transactionType: WalletTransactionTransactionTypeEnum.Outbound,
    })

    expect(screen.getByTitle('minus/medium')).toBeInTheDocument()
    expect(screen.queryByTestId('caption-pending')).not.toBeInTheDocument()
  })

  it('should render granted item properly', async () => {
    await prepare({
      transactionType: WalletTransactionTransactionTypeEnum.Inbound,
      transactionStatus: WalletTransactionTransactionStatusEnum.Granted,
    })

    expect(screen.getByTitle('plus/medium')).toBeInTheDocument()
    expect(screen.getByTestId('transaction-label')).toBeInTheDocument()
  })

  it('should render voided item properly', async () => {
    await prepare({
      transactionType: WalletTransactionTransactionTypeEnum.Outbound,
      transactionStatus: WalletTransactionTransactionStatusEnum.Voided,
    })

    expect(screen.getByTitle('minus/medium')).toBeInTheDocument()
    expect(screen.getByTestId('transaction-label')).toBeInTheDocument()
  })

  it('should render real time transaction', async () => {
    await prepare(undefined, true)

    expect(screen.getByTitle('pulse/medium')).toBeInTheDocument()
    expect(screen.queryByTestId('caption-pending')).not.toBeInTheDocument()
    expect(screen.getByTestId('credits')).toHaveTextContent(CREDITS)
    expect(screen.getByTestId('amount')).toHaveTextContent(AMOUNT)
  })

  it('should render automatic credits purchased for interval source', async () => {
    await prepare({
      source: WalletTransactionSourceEnum.Interval,
      transactionStatus: WalletTransactionTransactionStatusEnum.Purchased,
      transactionType: WalletTransactionTransactionTypeEnum.Inbound,
    })

    expect(screen.getByTestId('transaction-label')).toBeInTheDocument()
  })

  it('should render automatic credits purchased for threshold source', async () => {
    await prepare({
      source: WalletTransactionSourceEnum.Threshold,
      transactionStatus: WalletTransactionTransactionStatusEnum.Purchased,
      transactionType: WalletTransactionTransactionTypeEnum.Inbound,
    })

    expect(screen.getByTestId('transaction-label')).toBeInTheDocument()
  })

  it('should render inbound transaction with invoiced status using fallback label', async () => {
    await prepare({
      transactionType: WalletTransactionTransactionTypeEnum.Inbound,
      transactionStatus: WalletTransactionTransactionStatusEnum.Invoiced,
    })

    expect(screen.getByTestId('transaction-label')).toBeInTheDocument()
    expect(screen.getByTitle('plus/medium')).toBeInTheDocument()
  })

  it('should render real time transaction with zero amount for non premium user', async () => {
    jest.mock('~/hooks/useCurrentUser', () => ({
      useCurrentUser: () => ({
        isPremium: false,
        loading: false,
        currentUser: {
          id: '1',
          email: 'currentUser@mail.com',
          premium: false,
        },
      }),
    }))

    await prepare(undefined, true)

    expect(screen.getByTitle('pulse/medium')).toBeInTheDocument()
    expect(screen.queryByTestId('caption-pending')).not.toBeInTheDocument()
    expect(screen.getByTestId('credits')).toHaveTextContent('0')
    expect(screen.getByTestId('amount')).toHaveTextContent('0')
  })

  describe('GIVEN the transaction has priority and remaining credits columns', () => {
    describe('WHEN the transaction is inbound', () => {
      it('THEN should display the priority value', async () => {
        await prepare({
          transactionType: WalletTransactionTransactionTypeEnum.Inbound,
          priority: 5,
        })

        expect(screen.getByTestId(TRANSACTION_PRIORITY_DATA_TEST)).toHaveTextContent('5')
      })

      it('THEN should display remaining credits', async () => {
        await prepare({
          transactionType: WalletTransactionTransactionTypeEnum.Inbound,
          remainingCreditAmount: '50',
          remainingAmountCents: '5000',
        })

        expect(screen.getByTestId(TRANSACTION_REMAINING_CREDITS_DATA_TEST)).not.toHaveTextContent(
          '-',
        )
      })
    })

    describe('WHEN the transaction is outbound', () => {
      it('THEN should display "-" for priority', async () => {
        await prepare({
          transactionType: WalletTransactionTransactionTypeEnum.Outbound,
          priority: 5,
        })

        expect(screen.getByTestId(TRANSACTION_PRIORITY_DATA_TEST)).toHaveTextContent('-')
      })

      it('THEN should display "-" for remaining credits', async () => {
        await prepare({
          transactionType: WalletTransactionTransactionTypeEnum.Outbound,
          remainingCreditAmount: '50',
          remainingAmountCents: '5000',
        })

        expect(screen.getByTestId(TRANSACTION_REMAINING_CREDITS_DATA_TEST)).toHaveTextContent('-')
      })
    })

    describe('WHEN the transaction is a real-time transaction', () => {
      it('THEN should not display priority column', async () => {
        await prepare(
          {
            transactionType: WalletTransactionTransactionTypeEnum.Inbound,
            priority: 5,
          },
          true,
        )

        expect(screen.queryByTestId(TRANSACTION_PRIORITY_DATA_TEST)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the transaction list item has actions', () => {
    describe('WHEN pressing Enter on the item', () => {
      it('THEN should trigger onClick callback', async () => {
        const onClickMock = jest.fn()

        await prepare(
          {
            transactionType: WalletTransactionTransactionTypeEnum.Inbound,
          },
          false,
          onClickMock,
        )

        const allButtons = screen.getAllByRole('button') as HTMLElement[]
        const clickableDiv = allButtons[0]

        fireEvent.keyDown(clickableDiv, { key: 'Enter' })

        expect(onClickMock).toHaveBeenCalledTimes(1)
      })
    })

    describe('WHEN clicking the action menu', () => {
      it('THEN should show the copy button in the menu', async () => {
        const user = userEvent.setup()

        await prepare(
          {
            transactionType: WalletTransactionTransactionTypeEnum.Inbound,
          },
          false,
          jest.fn(),
        )

        const dotsButton = (screen.getByTestId('dots-horizontal/medium') as HTMLElement).closest(
          'button',
        ) as HTMLElement

        await user.click(dotsButton)

        await waitFor(() => {
          const buttons = screen.getAllByTestId('button') as HTMLElement[]
          const copyButton = buttons.find((btn) =>
            btn.querySelector('[data-test="duplicate/medium"]'),
          )

          expect(copyButton).toBeDefined()
        })
      })

      it('THEN should copy transaction ID to clipboard', async () => {
        const user = userEvent.setup()

        await prepare(
          {
            id: 'test-transaction-id',
            transactionType: WalletTransactionTransactionTypeEnum.Inbound,
          },
          false,
          jest.fn(),
        )

        const dotsButton = (screen.getByTestId('dots-horizontal/medium') as HTMLElement).closest(
          'button',
        ) as HTMLElement

        await user.click(dotsButton)

        await waitFor(() => {
          const buttons = screen.getAllByTestId('button') as HTMLElement[]
          const copyButton = buttons.find((btn) =>
            btn.querySelector('[data-test="duplicate/medium"]'),
          )

          expect(copyButton).toBeDefined()
        })

        const buttons = screen.getAllByTestId('button') as HTMLElement[]
        const copyButton = buttons.find((btn) =>
          btn.querySelector('[data-test="duplicate/medium"]'),
        ) as HTMLElement

        await user.click(copyButton)

        expect(copyToClipboard).toHaveBeenCalledWith('test-transaction-id')
        expect(addToast).toHaveBeenCalledWith({
          severity: 'info',
          translateKey: 'text_17412580835361rm20fysfba',
        })
      })

      it('THEN should trigger onClick when clicking the view details button', async () => {
        const user = userEvent.setup()
        const onClickMock = jest.fn()

        await prepare(
          {
            transactionType: WalletTransactionTransactionTypeEnum.Inbound,
          },
          false,
          onClickMock,
        )

        const dotsButton = (screen.getByTestId('dots-horizontal/medium') as HTMLElement).closest(
          'button',
        ) as HTMLElement

        await user.click(dotsButton)

        await waitFor(() => {
          const buttons = screen.getAllByTestId('button') as HTMLElement[]
          const viewButton = buttons.find((btn) => btn.querySelector('[data-test="eye/medium"]'))

          expect(viewButton).toBeDefined()
        })

        const buttons = screen.getAllByTestId('button') as HTMLElement[]
        const viewButton = buttons.find((btn) =>
          btn.querySelector('[data-test="eye/medium"]'),
        ) as HTMLElement

        await user.click(viewButton)

        expect(onClickMock).toHaveBeenCalled()
      })
    })
  })
})
