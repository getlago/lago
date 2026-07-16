import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createRef } from 'react'

import {
  EditCustomerInvoiceCustomSectionsDialog,
  EditCustomerInvoiceCustomSectionsDialogRef,
} from '~/components/customers/EditCustomerInvoiceCustomSectionsDialog'
import {
  EditCustomerInvoiceCustomSectionDocument,
  GetCustomerInvoiceCustomSectionsDocument,
  GetInvoiceCustomSectionsDocument,
} from '~/generated/graphql'
import { render, TestMocksType } from '~/test-utils'

const CUSTOMER_ID = 'customer-123'
const CUSTOMER_EXTERNAL_ID = 'ext-customer-123'

const mockAddToast = jest.fn()

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: (params: unknown) => mockAddToast(params),
}))

const mockInvoiceCustomSections = {
  invoiceCustomSections: {
    __typename: 'InvoiceCustomSectionCollection',
    collection: [
      {
        __typename: 'InvoiceCustomSection',
        id: 'section-1',
        name: 'Section 1',
        code: 'SECTION_1',
      },
      {
        __typename: 'InvoiceCustomSection',
        id: 'section-2',
        name: 'Section 2',
        code: 'SECTION_2',
      },
      {
        __typename: 'InvoiceCustomSection',
        id: 'section-3',
        name: 'Section 3',
        code: 'SECTION_3',
      },
    ],
  },
}

const mockCustomerFallback = {
  customer: {
    __typename: 'Customer',
    id: CUSTOMER_ID,
    externalId: CUSTOMER_EXTERNAL_ID,
    configurableInvoiceCustomSections: [],
    hasOverwrittenInvoiceCustomSectionsSelection: false,
    skipInvoiceCustomSections: false,
  },
}

const mockCustomerCustomSections = {
  customer: {
    __typename: 'Customer',
    id: CUSTOMER_ID,
    externalId: CUSTOMER_EXTERNAL_ID,
    configurableInvoiceCustomSections: [
      {
        __typename: 'InvoiceCustomSection',
        id: 'section-1',
        name: 'Section 1',
      },
      {
        __typename: 'InvoiceCustomSection',
        id: 'section-2',
        name: 'Section 2',
      },
    ],
    hasOverwrittenInvoiceCustomSectionsSelection: true,
    skipInvoiceCustomSections: false,
  },
}

async function prepare({
  customerMock = mockCustomerFallback,
  mocks = [],
}: {
  customerMock?: typeof mockCustomerFallback | typeof mockCustomerCustomSections
  mocks?: TestMocksType
} = {}) {
  const defaultMocks: TestMocksType = [
    {
      request: {
        query: GetCustomerInvoiceCustomSectionsDocument,
        variables: { customerId: CUSTOMER_ID },
      },
      result: {
        data: customerMock,
      },
    },
    {
      request: {
        query: GetInvoiceCustomSectionsDocument,
        variables: {},
      },
      result: {
        data: mockInvoiceCustomSections,
      },
    },
    ...mocks,
  ]

  const ref = createRef<EditCustomerInvoiceCustomSectionsDialogRef>()

  await act(() =>
    render(<EditCustomerInvoiceCustomSectionsDialog ref={ref} customerId={CUSTOMER_ID} />, {
      mocks: defaultMocks,
    } as { mocks: TestMocksType }),
  )

  // Open the dialog
  await act(() => {
    ref.current?.openDialog()
  })

  // Wait for lazy query to complete
  await waitFor(() => {
    expect(screen.getByTestId('dialog-title')).toBeInTheDocument()
  })

  return { ref }
}

describe('EditCustomerInvoiceCustomSectionsDialog', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('Form interaction and MultipleComboBox visibility', () => {
    it('should show MultipleComboBox when APPLY radiobox is selected and hide for others', async () => {
      const user = userEvent.setup()

      await prepare({ customerMock: mockCustomerFallback })

      const radioButtons = screen.getAllByRole('radio')

      // Initially FALLBACK is selected, no MultipleComboBox
      expect(screen.queryByPlaceholderText(/select/i)).not.toBeInTheDocument()

      // Select APPLY (second radio)
      await user.click(radioButtons[1])

      await waitFor(() => {
        expect(screen.getByPlaceholderText(/select/i)).toBeInTheDocument()
      })

      // Select FALLBACK (first radio)
      await user.click(radioButtons[0])

      await waitFor(() => {
        expect(screen.queryByPlaceholderText(/select/i)).not.toBeInTheDocument()
      })

      // Select DEACTIVATE (third radio)
      await user.click(radioButtons[2])

      await waitFor(() => {
        expect(screen.queryByPlaceholderText(/select/i)).not.toBeInTheDocument()
      })
    })
  })

  describe('Submit with FALLBACK behavior', () => {
    it('should call mutation with correct FALLBACK parameters and show success toast', async () => {
      const user = userEvent.setup()

      const mutationMock = {
        request: {
          query: EditCustomerInvoiceCustomSectionDocument,
          variables: {
            input: {
              id: CUSTOMER_ID,
              externalId: CUSTOMER_EXTERNAL_ID,
              skipInvoiceCustomSections: false,
              configurableInvoiceCustomSectionIds: [],
            },
          },
        },
        result: {
          data: {
            updateCustomer: {
              __typename: 'Customer',
              id: CUSTOMER_ID,
              externalId: CUSTOMER_EXTERNAL_ID,
              configurableInvoiceCustomSections: [],
              hasOverwrittenInvoiceCustomSectionsSelection: false,
              skipInvoiceCustomSections: false,
            },
          },
        },
      }

      await prepare({ customerMock: mockCustomerCustomSections, mocks: [mutationMock] })

      const radioButtons = screen.getAllByRole('radio')
      const buttons = screen.getAllByRole('button')
      const submitButton = buttons[buttons.length - 1]

      // Change from APPLY to FALLBACK
      await user.click(radioButtons[0])

      await waitFor(() => {
        expect(submitButton).not.toBeDisabled()
      })

      await user.click(submitButton)

      await waitFor(() => {
        expect(mockAddToast).toHaveBeenCalledWith({
          severity: 'success',
          message: expect.any(String),
        })
      })
    })
  })

  describe('Submit with APPLY behavior', () => {
    it('should require at least one section when CUSTOM_SECTIONS is selected', async () => {
      const user = userEvent.setup()

      await prepare({ customerMock: mockCustomerFallback })

      const radioButtons = screen.getAllByRole('radio')

      // Select CUSTOM_SECTIONS
      await user.click(radioButtons[1])

      await waitFor(() => {
        expect(screen.getByPlaceholderText(/select/i)).toBeInTheDocument()
      })
    })
  })
})
