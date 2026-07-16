import { MockedResponse } from '@apollo/client/testing'
import { act, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import {
  CLOSE_CREATE_TOPUP_BUTTON_DATA_TEST,
  CREATE_WALLET_TOP_UP_FORM_TEST_ID,
  SUBMIT_WALLET_DATA_TEST,
} from '~/components/wallets/utils/dataTestConstants'
import { addToast } from '~/core/apolloClient'
import {
  CreateCustomerWalletTransactionDocument,
  CurrencyEnum,
  GetCustomerInfosForWalletFormDocument,
  GetInvoiceStatusDocument,
  GetWalletForTopUpDocument,
  VoidInvoiceDocument,
} from '~/generated/graphql'
import { render, TestMocksType } from '~/test-utils'

import CreateWalletTopUp from '../CreateWalletTopUp'

// Mock dependencies
jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    organization: {
      id: 'org-1',
      defaultCurrency: 'USD',
    },
    hasFeatureFlag: jest.fn(() => false),
  }),
}))

const mockGoBack = jest.fn()

jest.mock('~/hooks/core/useLocationHistory', () => ({
  useLocationHistory: () => ({
    goBack: mockGoBack,
  }),
}))

jest.mock('~/hooks/usePermissionsInvoiceActions', () => ({
  usePermissionsInvoiceActions: () => ({
    canVoid: jest.fn(() => true),
  }),
}))

// Mock data
const mockWalletData = {
  wallet: {
    id: 'wallet-1',
    name: 'Test Wallet',
    currency: CurrencyEnum.Usd,
    rateAmount: '1.0',
    invoiceRequiresSuccessfulPayment: false,
    paidTopUpMinAmountCents: null,
    paidTopUpMaxAmountCents: null,
    priority: 50,
  },
}

const mockCustomerData = {
  customer: {
    id: 'customer-1',
    externalId: 'ext-customer-1',
    currency: CurrencyEnum.Usd,
    timezone: 'UTC',
  },
}

// Mock factories
const createWalletForTopUpMock = (): MockedResponse => ({
  request: {
    query: GetWalletForTopUpDocument,
    variables: { walletId: 'wallet-1' },
  },
  result: {
    data: mockWalletData,
  },
})

const createCustomerInfoMock = (): MockedResponse => ({
  request: {
    query: GetCustomerInfosForWalletFormDocument,
    variables: { id: 'customer-1' },
  },
  result: {
    data: mockCustomerData,
  },
})

const createMutationMock = (
  onVariablesCaptured?: (variables: Record<string, unknown>) => void,
): MockedResponse => ({
  request: {
    query: CreateCustomerWalletTransactionDocument,
  },
  variableMatcher: (variables: Record<string, unknown>) => {
    onVariablesCaptured?.(variables)
    return true
  },
  result: {
    data: {
      createCustomerWalletTransaction: {
        collection: [{ id: 'trans-1' }],
      },
    },
  },
})

const createInvoiceStatusMock = (): MockedResponse => ({
  request: {
    query: GetInvoiceStatusDocument,
    variables: { id: 'voided-invoice-1' },
  },
  result: {
    data: {
      invoice: {
        id: 'voided-invoice-1',
        status: 'finalized',
      },
    },
  },
})

const createVoidInvoiceMock = (
  onVariablesCaptured?: (variables: Record<string, unknown>) => void,
): MockedResponse => ({
  request: {
    query: VoidInvoiceDocument,
  },
  variableMatcher: (variables: Record<string, unknown>) => {
    onVariablesCaptured?.(variables)
    return true
  },
  result: {
    data: {
      voidInvoice: {
        id: 'voided-invoice-1',
        status: 'voided',
      },
    },
  },
})

const getDefaultMocks = (
  onMutationVariables?: (variables: Record<string, unknown>) => void,
): TestMocksType =>
  [
    createWalletForTopUpMock(),
    createCustomerInfoMock(),
    createMutationMock(onMutationVariables),
  ] as TestMocksType

// Helpers
const getPaidCreditsInput = () =>
  document.querySelector('input[name="paidCredits"]') as HTMLInputElement

const getPriorityInput = () => document.querySelector('input[name="priority"]') as HTMLInputElement

describe('CreateWalletTopUp', () => {
  beforeEach(() => {
    jest.clearAllMocks()

    const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

    useParamsMock.mockReturnValue({
      customerId: 'customer-1',
      walletId: 'wallet-1',
      voidedInvoiceId: '',
    })
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN the wallet data is loading', () => {
    describe('WHEN the component renders', () => {
      it('THEN should display the close button', () => {
        render(<CreateWalletTopUp />, { mocks: getDefaultMocks() })

        expect(screen.getByTestId(CLOSE_CREATE_TOPUP_BUTTON_DATA_TEST)).toBeInTheDocument()
      })

      it('THEN should not display the form section', () => {
        render(<CreateWalletTopUp />, { mocks: getDefaultMocks() })

        expect(screen.queryByTestId(CREATE_WALLET_TOP_UP_FORM_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the wallet data is loaded', () => {
    describe('WHEN the component renders', () => {
      it('THEN should display the form section', async () => {
        render(<CreateWalletTopUp />, { mocks: getDefaultMocks() })

        await waitFor(() => {
          expect(screen.getByTestId(CREATE_WALLET_TOP_UP_FORM_TEST_ID)).toBeInTheDocument()
        })
      })

      it.each([
        ['close button', CLOSE_CREATE_TOPUP_BUTTON_DATA_TEST],
        ['submit button', SUBMIT_WALLET_DATA_TEST],
      ])('THEN should display the %s', async (_, testId) => {
        render(<CreateWalletTopUp />, { mocks: getDefaultMocks() })

        await waitFor(() => {
          expect(screen.getByTestId(testId)).toBeInTheDocument()
        })
      })

      it('THEN should display the submit button as disabled initially', async () => {
        render(<CreateWalletTopUp />, { mocks: getDefaultMocks() })

        await waitFor(() => {
          expect(screen.getByTestId(CREATE_WALLET_TOP_UP_FORM_TEST_ID)).toBeInTheDocument()
        })

        expect(screen.getByTestId(SUBMIT_WALLET_DATA_TEST)).toBeDisabled()
      })

      it('THEN should display the paid credits input', async () => {
        render(<CreateWalletTopUp />, { mocks: getDefaultMocks() })

        await waitFor(() => {
          expect(getPaidCreditsInput()).toBeInTheDocument()
        })
      })

      it('THEN should display the priority input with default value', async () => {
        render(<CreateWalletTopUp />, { mocks: getDefaultMocks() })

        await waitFor(() => {
          const priorityInput = getPriorityInput()

          expect(priorityInput).toBeInTheDocument()
          expect(priorityInput).toHaveValue('50')
        })
      })
    })

    describe('WHEN user fills in paid credits', () => {
      it('THEN should enable the submit button', async () => {
        const user = userEvent.setup()

        render(<CreateWalletTopUp />, { mocks: getDefaultMocks() })

        await waitFor(() => {
          expect(getPaidCreditsInput()).toBeInTheDocument()
        })

        await user.type(getPaidCreditsInput(), '10')

        await waitFor(() => {
          expect(screen.getByTestId(SUBMIT_WALLET_DATA_TEST)).not.toBeDisabled()
        })
      })
    })
  })

  describe('GIVEN the user clicks the close button', () => {
    describe('WHEN the form is not dirty', () => {
      it('THEN should navigate back', async () => {
        const user = userEvent.setup()

        render(<CreateWalletTopUp />, { mocks: getDefaultMocks() })

        await waitFor(() => {
          expect(screen.getByTestId(CREATE_WALLET_TOP_UP_FORM_TEST_ID)).toBeInTheDocument()
        })

        await user.click(screen.getByTestId(CLOSE_CREATE_TOPUP_BUTTON_DATA_TEST))

        expect(mockGoBack).toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the user switches to free credits', () => {
    describe('WHEN the free credits tab is clicked', () => {
      it('THEN should display the granted credits input', async () => {
        const user = userEvent.setup()

        render(<CreateWalletTopUp />, { mocks: getDefaultMocks() })

        await waitFor(() => {
          expect(screen.getByTestId(CREATE_WALLET_TOP_UP_FORM_TEST_ID)).toBeInTheDocument()
        })

        // Click the Free Credits tab button
        const freeCreditsTab = screen.getByRole('button', {
          name: /text_1770376670114piyn9eibuhm/,
        })

        await user.click(freeCreditsTab)

        await waitFor(() => {
          expect(document.querySelector('input[name="grantedCredits"]')).toBeInTheDocument()
        })

        // paidCredits input should be gone
        expect(document.querySelector('input[name="paidCredits"]')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the form is submitted', () => {
    describe('WHEN priority has the default value', () => {
      it('THEN should send priority 50 in the mutation', async () => {
        const user = userEvent.setup()
        let capturedVariables: Record<string, unknown> | undefined

        render(<CreateWalletTopUp />, {
          mocks: getDefaultMocks((vars) => {
            capturedVariables = vars
          }),
        })

        await waitFor(() => {
          expect(getPaidCreditsInput()).toBeInTheDocument()
        })

        await user.type(getPaidCreditsInput(), '10')

        await waitFor(() => {
          expect(screen.getByTestId(SUBMIT_WALLET_DATA_TEST)).not.toBeDisabled()
        })

        await act(async () => {
          await user.click(screen.getByTestId(SUBMIT_WALLET_DATA_TEST))
        })

        await waitFor(() => {
          expect(capturedVariables).toBeDefined()
          expect(
            (capturedVariables as Record<string, Record<string, unknown>>).input.priority,
          ).toBe(50)
        })
      })
    })

    describe('WHEN priority is changed to a custom value', () => {
      it('THEN should send the custom priority in the mutation', async () => {
        const user = userEvent.setup()
        let capturedVariables: Record<string, unknown> | undefined

        render(<CreateWalletTopUp />, {
          mocks: getDefaultMocks((vars) => {
            capturedVariables = vars
          }),
        })

        await waitFor(() => {
          expect(getPriorityInput()).toBeInTheDocument()
        })

        // Clear default priority and set a new one
        await user.clear(getPriorityInput())
        await user.type(getPriorityInput(), '25')

        // Fill in paid credits to make form dirty and valid
        await user.type(getPaidCreditsInput(), '10')

        await waitFor(() => {
          expect(screen.getByTestId(SUBMIT_WALLET_DATA_TEST)).not.toBeDisabled()
        })

        await act(async () => {
          await user.click(screen.getByTestId(SUBMIT_WALLET_DATA_TEST))
        })

        await waitFor(() => {
          expect(capturedVariables).toBeDefined()
          expect(
            (capturedVariables as Record<string, Record<string, unknown>>).input.priority,
          ).toBe(25)
        })
      })
    })

    describe('WHEN submitting with free credits', () => {
      it('THEN should send grantedCredits and zero paidCredits', async () => {
        const user = userEvent.setup()
        let capturedVariables: Record<string, unknown> | undefined

        render(<CreateWalletTopUp />, {
          mocks: getDefaultMocks((vars) => {
            capturedVariables = vars
          }),
        })

        await waitFor(() => {
          expect(screen.getByTestId(CREATE_WALLET_TOP_UP_FORM_TEST_ID)).toBeInTheDocument()
        })

        // Switch to Free Credits tab
        const freeCreditsTab = screen.getByRole('button', {
          name: /text_1770376670114piyn9eibuhm/,
        })

        await user.click(freeCreditsTab)

        await waitFor(() => {
          expect(document.querySelector('input[name="grantedCredits"]')).toBeInTheDocument()
        })

        const grantedCreditsInput = document.querySelector(
          'input[name="grantedCredits"]',
        ) as HTMLInputElement

        await user.type(grantedCreditsInput, '5')

        await waitFor(() => {
          expect(screen.getByTestId(SUBMIT_WALLET_DATA_TEST)).not.toBeDisabled()
        })

        await act(async () => {
          await user.click(screen.getByTestId(SUBMIT_WALLET_DATA_TEST))
        })

        await waitFor(() => {
          expect(capturedVariables).toBeDefined()

          const input = (capturedVariables as Record<string, Record<string, unknown>>).input

          expect(input.grantedCredits).toBe('5')
          expect(input.paidCredits).toBe('0')
          expect(input.priority).toBe(50)
        })
      })
    })

    describe('WHEN there is a voided invoice to replace', () => {
      it('THEN should void the invoice before creating the top up', async () => {
        const user = userEvent.setup()
        let voidCapturedVars: Record<string, unknown> | undefined
        let createCapturedVars: Record<string, unknown> | undefined

        const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

        useParamsMock.mockReturnValue({
          customerId: 'customer-1',
          walletId: 'wallet-1',
          voidedInvoiceId: 'voided-invoice-1',
        })

        const mocks = [
          createWalletForTopUpMock(),
          createCustomerInfoMock(),
          createInvoiceStatusMock(),
          createVoidInvoiceMock((vars) => {
            voidCapturedVars = vars
          }),
          createMutationMock((vars) => {
            createCapturedVars = vars
          }),
        ] as TestMocksType

        render(<CreateWalletTopUp />, { mocks })

        await waitFor(() => {
          expect(getPaidCreditsInput()).toBeInTheDocument()
        })

        await user.type(getPaidCreditsInput(), '10')

        await waitFor(() => {
          expect(screen.getByTestId(SUBMIT_WALLET_DATA_TEST)).not.toBeDisabled()
        })

        await act(async () => {
          await user.click(screen.getByTestId(SUBMIT_WALLET_DATA_TEST))
        })

        await waitFor(() => {
          expect(voidCapturedVars).toBeDefined()
          expect((voidCapturedVars as Record<string, Record<string, unknown>>).input.id).toBe(
            'voided-invoice-1',
          )
        })

        await waitFor(() => {
          expect(createCapturedVars).toBeDefined()
          expect(
            (createCapturedVars as Record<string, Record<string, unknown>>).input.priority,
          ).toBe(50)
        })
      })
    })

    describe('WHEN mutation succeeds', () => {
      it('THEN should show a success toast', async () => {
        const user = userEvent.setup()

        render(<CreateWalletTopUp />, { mocks: getDefaultMocks() })

        await waitFor(() => {
          expect(getPaidCreditsInput()).toBeInTheDocument()
        })

        await user.type(getPaidCreditsInput(), '10')

        await waitFor(() => {
          expect(screen.getByTestId(SUBMIT_WALLET_DATA_TEST)).not.toBeDisabled()
        })

        await act(async () => {
          await user.click(screen.getByTestId(SUBMIT_WALLET_DATA_TEST))
        })

        await waitFor(() => {
          expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'success' }))
        })
      })
    })
  })
})
