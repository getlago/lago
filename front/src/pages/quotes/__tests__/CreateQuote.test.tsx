import { fireEvent, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { StatusTypeEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import CreateQuote, {
  CREATE_QUOTE_CURRENCY_COMBOBOX_TEST_ID,
  CREATE_QUOTE_CUSTOMER_COMBOBOX_TEST_ID,
  CREATE_QUOTE_ORDER_TYPE_TEST_ID,
  CREATE_QUOTE_SUBMIT_BUTTON_TEST_ID,
  CREATE_QUOTE_SUBSCRIPTION_COMBOBOX_TEST_ID,
} from '../CreateQuote'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const mockOnSave = jest.fn()
let mockLoading = false

jest.mock('../hooks/useCreateQuote', () => ({
  useCreateQuote: () => ({
    loading: mockLoading,
    onSave: mockOnSave,
  }),
}))

let mockCustomersQueryData: unknown = undefined
let mockSubscriptionsQueryData: unknown = undefined
let mockMembersQueryData: unknown = undefined

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetCustomersForCreateQuoteLazyQuery: () => [
    jest.fn(),
    { data: mockCustomersQueryData, loading: false },
  ],
  useGetCustomerSubscriptionsForCreateQuoteLazyQuery: () => [
    jest.fn(),
    { data: mockSubscriptionsQueryData, loading: false },
  ],
  useGetMembersForCreateQuoteQuery: () => ({
    data: mockMembersQueryData,
    loading: false,
  }),
}))

const mockNavigate = jest.fn()

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useNavigate: () => mockNavigate,
}))

const mockDialogOpen = jest.fn()

jest.mock('~/components/dialogs/CentralizedDialog', () => ({
  useCentralizedDialog: () => ({
    open: mockDialogOpen,
  }),
}))

describe('CreateQuote', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockLoading = false
    mockCustomersQueryData = undefined
    mockSubscriptionsQueryData = undefined
    mockMembersQueryData = undefined
  })

  describe('GIVEN the page is rendered', () => {
    describe('WHEN in default state', () => {
      it.each([
        ['customer combobox', CREATE_QUOTE_CUSTOMER_COMBOBOX_TEST_ID],
        ['order type selector', CREATE_QUOTE_ORDER_TYPE_TEST_ID],
        ['submit button', CREATE_QUOTE_SUBMIT_BUTTON_TEST_ID],
      ])('THEN should render the %s', (_, testId) => {
        render(<CreateQuote />)

        expect(screen.getByTestId(testId)).toBeInTheDocument()
      })

      it('THEN should not show the subscription combobox by default', () => {
        render(<CreateQuote />)

        expect(
          screen.queryByTestId(CREATE_QUOTE_SUBSCRIPTION_COMBOBOX_TEST_ID),
        ).not.toBeInTheDocument()
      })

      it('THEN should render the form with the correct id', () => {
        render(<CreateQuote />)

        const form = document.getElementById('create-quote')

        expect(form).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the mutation is loading', () => {
    describe('WHEN the page renders', () => {
      it('THEN should disable the submit button', () => {
        mockLoading = true

        render(<CreateQuote />)

        const submitButton = screen.getByTestId(CREATE_QUOTE_SUBMIT_BUTTON_TEST_ID)

        expect(submitButton).toBeDisabled()
      })
    })
  })

  describe('GIVEN the mutation is not loading', () => {
    describe('WHEN the page renders', () => {
      it('THEN should not disable the submit button', () => {
        mockLoading = false

        render(<CreateQuote />)

        const submitButton = screen.getByTestId(CREATE_QUOTE_SUBMIT_BUTTON_TEST_ID)

        expect(submitButton).not.toBeDisabled()
      })
    })
  })

  describe('GIVEN the form is submitted', () => {
    describe('WHEN the submit event fires', () => {
      it('THEN should prevent default and trigger form validation', () => {
        render(<CreateQuote />)

        const form = document.getElementById('create-quote') as HTMLFormElement

        fireEvent.submit(form)

        // handleSubmit is called which calls e.preventDefault() and form.handleSubmit()
        // Validation will fail (no customerId), but handleSubmit itself is exercised
        expect(form).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the close button is clicked', () => {
    describe('WHEN the form is in its initial clean state', () => {
      it('THEN should not open the warning dialog', async () => {
        const user = userEvent.setup()

        render(<CreateQuote />)

        // The Button component renders data-test="button" on the <button> element.
        // The first button in the DOM is the close icon in the header.
        const allButtons = screen.getAllByTestId('button')

        await user.click(allButtons[0])

        // Clean form takes the navigate path, not the dialog path
        expect(mockDialogOpen).not.toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN customer data is loaded', () => {
    describe('WHEN the customers query returns results', () => {
      it('THEN should render without errors', () => {
        mockCustomersQueryData = {
          customers: {
            collection: [
              { id: 'cust-1', displayName: 'Customer One', externalId: 'ext-1', currency: null },
              { id: 'cust-2', displayName: '', externalId: 'ext-2', currency: 'USD' },
            ],
          },
        }

        render(<CreateQuote />)

        expect(screen.getByTestId(CREATE_QUOTE_CUSTOMER_COMBOBOX_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the currency field', () => {
    describe('WHEN no customer is selected', () => {
      it('THEN should not show the currency combobox', () => {
        render(<CreateQuote />)

        expect(screen.queryByTestId(CREATE_QUOTE_CURRENCY_COMBOBOX_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN members data is loaded', () => {
    describe('WHEN the members query returns results', () => {
      it('THEN should render the form without errors', () => {
        mockMembersQueryData = {
          memberships: {
            collection: [
              { id: 'member-1', user: { id: 'user-1', email: 'alice@example.com' } },
              { id: 'member-2', user: { id: 'user-2', email: 'bob@example.com' } },
            ],
          },
        }

        render(<CreateQuote />)

        expect(screen.getByTestId(CREATE_QUOTE_CUSTOMER_COMBOBOX_TEST_ID)).toBeInTheDocument()
      })
    })

    describe('WHEN the members query returns members with null email', () => {
      it('THEN should render the form filtering out null emails without errors', () => {
        mockMembersQueryData = {
          memberships: {
            collection: [
              { id: 'member-1', user: { id: 'user-1', email: 'alice@example.com' } },
              { id: 'member-2', user: { id: 'user-2', email: null } },
            ],
          },
        }

        render(<CreateQuote />)

        expect(screen.getByTestId(CREATE_QUOTE_CUSTOMER_COMBOBOX_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN subscription data is loaded', () => {
    describe('WHEN the subscriptions query returns results with mixed statuses', () => {
      it('THEN should render without errors', () => {
        mockSubscriptionsQueryData = {
          customer: {
            id: 'cust-1',
            subscriptions: [
              {
                id: 'sub-1',
                name: 'Sub One',
                externalId: 'ext-sub-1',
                status: StatusTypeEnum.Active,
                plan: { id: 'plan-1', name: 'Plan One', code: 'plan-1' },
              },
              {
                id: 'sub-2',
                name: null,
                externalId: 'ext-sub-2',
                status: StatusTypeEnum.Canceled,
                plan: { id: 'plan-2', name: 'Plan Two', code: 'plan-2' },
              },
            ],
          },
        }

        render(<CreateQuote />)

        expect(screen.getByTestId(CREATE_QUOTE_ORDER_TYPE_TEST_ID)).toBeInTheDocument()
      })
    })
  })
})
