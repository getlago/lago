import { act, cleanup, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { EditCustomerVatRateDialog } from '~/components/customers/EditCustomerVatRateDialog'
import {
  MUI_INPUT_BASE_ROOT_CLASSNAME,
  SEARCH_TAX_INPUT_FOR_CUSTOMER_CLASSNAME,
} from '~/core/constants/form'
import { CREATE_TAX_ROUTE } from '~/core/router'
import { GetTaxRatesForEditCustomerDocument } from '~/generated/graphql'
import { render, TestMocksType } from '~/test-utils'

const membershipWithPermissions = {
  id: '2',
  organization: {
    id: '3',
    name: 'Organization',
    logoUrl: 'https://logo.com',
  },
  permissions: {
    organizationTaxesUpdate: true,
  },
}

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({
    currentMembership: membershipWithPermissions,
  }),
}))

async function prepare({
  mocks = [
    {
      request: {
        query: GetTaxRatesForEditCustomerDocument,
        variables: { limit: 20 },
      },
      result: {
        data: {
          taxes: {
            metadata: {
              currentPage: 1,
              totalPages: 1,
            },
            collection: [],
          },
        },
      },
    },
  ],
}: { mocks?: TestMocksType } = {}) {
  const customer = {
    id: '1234',
    name: 'Customer Name',
    displayName: 'Customer name',
    externalId: '4567',
  }

  await act(() =>
    render(<EditCustomerVatRateDialog forceOpen customer={customer} />, {
      mocks,
    }),
  )
}

describe('EditCustomerVatRateDialog', () => {
  afterEach(cleanup)

  it('renders', async () => {
    await prepare()

    expect(screen.queryByTestId('edit-customer-vat-rate-dialog')).toBeInTheDocument()
  })

  it('should propose to create a new tax if none exists and have permissions', async () => {
    await prepare()

    userEvent
      .click(
        screen
          .queryByTestId('edit-customer-vat-rate-dialog')
          ?.querySelector(
            `.${SEARCH_TAX_INPUT_FOR_CUSTOMER_CLASSNAME} .${MUI_INPUT_BASE_ROOT_CLASSNAME}`,
          ) as HTMLElement,
      )
      .then(() => {
        expect(screen.queryByTestId('combobox-item-Create a tax_rate')).toBeInTheDocument()
        expect(
          screen.queryByTestId('combobox-item-Create a tax_rate')?.querySelector(`a`),
        ).toHaveAttribute('href', CREATE_TAX_ROUTE)
      })
  })
})
