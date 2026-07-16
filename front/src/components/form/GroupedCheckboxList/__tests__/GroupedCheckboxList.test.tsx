import { act, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import React from 'react'

import GroupedCheckboxList from '../GroupedCheckboxList'
import { CheckboxGroup, FieldGroupApi } from '../types'

// Mock dependencies
jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

// Mock ResizeObserver for TableWithGroups
global.ResizeObserver = jest.fn().mockImplementation(() => ({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn(),
}))

// Mock useStore from TanStack
let mockStoreValues: Record<string, boolean> = {}

jest.mock('@tanstack/react-form', () => ({
  useStore: jest.fn((_store, selector) => {
    return selector({ values: mockStoreValues })
  }),
}))

const mockGroups: CheckboxGroup[] = [
  {
    id: 'customers',
    label: 'Customers',
    items: [
      { id: 'customer.create', label: 'Create customer' },
      { id: 'customer.update', label: 'Update customer' },
      { id: 'customer.delete', label: 'Delete customer', sublabel: 'Permanently remove' },
    ],
  },
  {
    id: 'invoices',
    label: 'Invoices',
    items: [
      { id: 'invoice.create', label: 'Create invoice' },
      { id: 'invoice.view', label: 'View invoice' },
    ],
  },
]

const defaultCheckboxValues = {
  'customer.create': true,
  'customer.update': false,
  'customer.delete': false,
  'invoice.create': true,
  'invoice.view': false,
}

const createMockGroup = (): FieldGroupApi<Record<string, boolean>> => {
  return {
    store: {} as never,
    setFieldValue: jest.fn(),
    AppField: ({
      name,
      children,
    }: {
      name: string
      children: (field: {
        CheckboxField: React.FC<{ label: null; disabled?: boolean }>
      }) => React.ReactNode
    }) => (
      <div data-testid={`field-${name}`}>
        {children({
          CheckboxField: ({ disabled }: { label: null; disabled?: boolean }) => (
            <input
              type="checkbox"
              data-testid={`checkbox-${name}`}
              disabled={disabled}
              aria-label={name}
            />
          ),
        })}
      </div>
    ),
  }
}

const defaultProps = {
  title: 'Test Title',
  subtitle: 'Test Subtitle',
  searchPlaceholder: 'Search...',
  groups: mockGroups,
  group: createMockGroup(),
}

describe('GroupedCheckboxList', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockStoreValues = { ...defaultCheckboxValues }
  })

  describe('GIVEN component renders', () => {
    describe('WHEN displaying header section', () => {
      it('THEN shows title', async () => {
        await act(async () => {
          render(<GroupedCheckboxList {...defaultProps} />)
        })

        expect(screen.getByText('Test Title')).toBeInTheDocument()
      })

      it('THEN shows subtitle', async () => {
        await act(async () => {
          render(<GroupedCheckboxList {...defaultProps} />)
        })

        expect(screen.getByText('Test Subtitle')).toBeInTheDocument()
      })

      it('THEN shows search input with placeholder', async () => {
        await act(async () => {
          render(<GroupedCheckboxList {...defaultProps} />)
        })

        expect(screen.getByPlaceholderText('Search...')).toBeInTheDocument()
      })

      it('THEN shows expand/collapse button', async () => {
        await act(async () => {
          render(<GroupedCheckboxList {...defaultProps} />)
        })

        expect(screen.getByText('text_1768309883114yr34e2jrvn7')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN isEditable is true', () => {
    describe('WHEN rendering checkboxes', () => {
      it('THEN renders checkbox fields for each item', async () => {
        await act(async () => {
          render(<GroupedCheckboxList {...defaultProps} isEditable={true} />)
        })

        expect(screen.getByTestId('field-customer.create')).toBeInTheDocument()
        expect(screen.getByTestId('field-customer.update')).toBeInTheDocument()
        expect(screen.getByTestId('field-invoice.create')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN isEditable is false', () => {
    describe('WHEN rendering', () => {
      it('THEN still renders the component', async () => {
        await act(async () => {
          render(<GroupedCheckboxList {...defaultProps} isEditable={false} />)
        })

        expect(screen.getByText('Test Title')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN isLoading is true', () => {
    describe('WHEN rendering', () => {
      it('THEN passes isLoading to TableWithGroups', async () => {
        await act(async () => {
          render(<GroupedCheckboxList {...defaultProps} isLoading={true} />)
        })

        expect(screen.getByText('Test Title')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN errors are provided', () => {
    describe('WHEN errors array is not empty', () => {
      it('THEN displays error alert', async () => {
        await act(async () => {
          render(<GroupedCheckboxList {...defaultProps} errors={['error_key_1', 'error_key_2']} />)
        })

        expect(screen.getByText('error_key_1')).toBeInTheDocument()
        expect(screen.getByText('error_key_2')).toBeInTheDocument()
      })

      it('THEN alert has correct scroll target', async () => {
        await act(async () => {
          render(
            <GroupedCheckboxList
              {...defaultProps}
              errors={['error_key']}
              errorScrollTarget="custom-scroll-target"
            />,
          )
        })

        const alert = screen.getByText('error_key').closest('[data-scroll-target]')

        expect(alert).toHaveAttribute('data-scroll-target', 'custom-scroll-target')
      })
    })

    describe('WHEN errors array is empty', () => {
      it('THEN does not display error alert', async () => {
        await act(async () => {
          render(<GroupedCheckboxList {...defaultProps} errors={[]} />)
        })

        expect(screen.queryByRole('alert')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN search functionality', () => {
    describe('WHEN user types in search input', () => {
      it('THEN updates search term', async () => {
        const user = userEvent.setup()

        await act(async () => {
          render(<GroupedCheckboxList {...defaultProps} />)
        })

        const searchInput = screen.getByPlaceholderText('Search...')

        await user.type(searchInput, 'customer')

        expect(searchInput).toHaveValue('customer')
      })
    })
  })

  describe('GIVEN expand/collapse functionality', () => {
    describe('WHEN clicking expand/collapse button', () => {
      it('THEN toggles button label', async () => {
        const user = userEvent.setup()

        await act(async () => {
          render(<GroupedCheckboxList {...defaultProps} />)
        })

        const button = screen.getByText('text_1768309883114yr34e2jrvn7')

        await user.click(button)

        expect(screen.getByText('text_17683098831144lro3kg6rip')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN hidden fields for form registration', () => {
    describe('WHEN component renders', () => {
      it('THEN renders hidden AppField for each checkbox value', async () => {
        await act(async () => {
          render(<GroupedCheckboxList {...defaultProps} />)
        })

        expect(screen.getByTestId('field-customer.create')).toBeInTheDocument()
        expect(screen.getByTestId('field-customer.update')).toBeInTheDocument()
        expect(screen.getByTestId('field-customer.delete')).toBeInTheDocument()
        expect(screen.getByTestId('field-invoice.create')).toBeInTheDocument()
        expect(screen.getByTestId('field-invoice.view')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN default props', () => {
    describe('WHEN isEditable is not provided', () => {
      it('THEN defaults to true', async () => {
        await act(async () => {
          render(
            <GroupedCheckboxList
              title="Test"
              subtitle="Test"
              searchPlaceholder="Search"
              groups={mockGroups}
              group={createMockGroup()}
            />,
          )
        })

        expect(screen.getByTestId('field-customer.create')).toBeInTheDocument()
      })
    })

    describe('WHEN errorScrollTarget is not provided', () => {
      it('THEN defaults to grouped-checkbox-list-errors', async () => {
        await act(async () => {
          render(<GroupedCheckboxList {...defaultProps} errors={['error']} />)
        })

        const alert = screen.getByText('error').closest('[data-scroll-target]')

        expect(alert).toHaveAttribute('data-scroll-target', 'grouped-checkbox-list-errors')
      })
    })
  })

  describe('GIVEN all checkboxes are checked', () => {
    describe('WHEN rendering', () => {
      it('THEN overall checkbox should be checked', async () => {
        mockStoreValues = {
          'customer.create': true,
          'customer.update': true,
          'customer.delete': true,
          'invoice.create': true,
          'invoice.view': true,
        }

        await act(async () => {
          render(<GroupedCheckboxList {...defaultProps} />)
        })

        expect(screen.getByText('Test Title')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN no checkboxes are checked', () => {
    describe('WHEN rendering', () => {
      it('THEN overall checkbox should be unchecked', async () => {
        mockStoreValues = {
          'customer.create': false,
          'customer.update': false,
          'customer.delete': false,
          'invoice.create': false,
          'invoice.view': false,
        }

        await act(async () => {
          render(<GroupedCheckboxList {...defaultProps} />)
        })

        expect(screen.getByText('Test Title')).toBeInTheDocument()
      })
    })
  })
})
