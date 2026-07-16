import { act, screen } from '@testing-library/react'
import { createRef } from 'react'

import { CurrencyEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { VoidWalletDialog, VoidWalletDialogRef } from '../VoidWalletDialog'

const mockCreateVoidTransaction = jest.fn()

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useCreateCustomerWalletTransactionMutation: () => [mockCreateVoidTransaction],
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

describe('VoidWalletDialog', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

    useParamsMock.mockReturnValue({ customerId: 'customer-1' })
  })

  describe('GIVEN the dialog ref', () => {
    describe('WHEN openDialog is called with undefined', () => {
      it('THEN should not open dialog', () => {
        const ref = createRef<VoidWalletDialogRef>()

        render(<VoidWalletDialog ref={ref} />)

        act(() => {
          ref.current?.openDialog(undefined)
        })

        expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
      })
    })

    describe('WHEN openDialog is called with wallet data', () => {
      it('THEN should show the dialog', () => {
        const ref = createRef<VoidWalletDialogRef>()

        render(<VoidWalletDialog ref={ref} />)

        act(() => {
          ref.current?.openDialog({
            walletId: 'wallet-1',
            creditsBalance: 100,
            currency: CurrencyEnum.Usd,
            rateAmount: 1,
          })
        })

        expect(screen.getByRole('dialog')).toBeInTheDocument()
      })
    })
  })
})
