import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { TaxForTaxesSelectorSectionFragment } from '~/generated/graphql'
import { render } from '~/test-utils'

import {
  buildTaxChipTestId,
  TAXES_SELECTOR_ADD_BUTTON_TEST_ID,
  TAXES_SELECTOR_COMBOBOX_CONTAINER_TEST_ID,
  TAXES_SELECTOR_DESCRIPTION_TEST_ID,
  TAXES_SELECTOR_DISMISS_BUTTON_TEST_ID,
  TAXES_SELECTOR_LIST_TEST_ID,
  TAXES_SELECTOR_SECTION_TEST_ID,
  TAXES_SELECTOR_TITLE_TEST_ID,
  TaxesSelectorSection,
  TaxesSelectorSectionProps,
} from '../TaxesSelectorSection'

// Mock scrollIntoView since JSDOM doesn't support it
Element.prototype.scrollIntoView = jest.fn()

const mockOnUpdate = jest.fn()

type TestProps = TaxesSelectorSectionProps<TaxForTaxesSelectorSectionFragment>

const defaultProps: TestProps = {
  title: 'Taxes',
  taxes: [],
  comboboxSelector: 'test-combobox',
  onUpdate: mockOnUpdate,
}

const mockTaxes: TaxForTaxesSelectorSectionFragment[] = [
  { id: 'tax-1', code: 'VAT', name: 'VAT', rate: 20 },
  { id: 'tax-2', code: 'GST', name: 'GST', rate: 10 },
]

async function prepare(props: Partial<TestProps> = {}): Promise<void> {
  await act(() => render(<TaxesSelectorSection {...defaultProps} {...props} />))
}

describe('TaxesSelectorSection', () => {
  afterEach(() => {
    cleanup()
    mockOnUpdate.mockClear()
  })

  describe('Snapshots', () => {
    it('renders with title only', async () => {
      const { container } = render(<TaxesSelectorSection {...defaultProps} />)

      expect(container).toMatchSnapshot()
    })

    it('renders with title and description', async () => {
      const { container } = render(
        <TaxesSelectorSection {...defaultProps} description="Select applicable taxes" />,
      )

      expect(container).toMatchSnapshot()
    })

    it('renders with taxes', async () => {
      const { container } = render(<TaxesSelectorSection {...defaultProps} taxes={mockTaxes} />)

      expect(container).toMatchSnapshot()
    })

    it('renders with title, description and taxes', async () => {
      const { container } = render(
        <TaxesSelectorSection
          {...defaultProps}
          description="Select applicable taxes"
          taxes={mockTaxes}
        />,
      )

      expect(container).toMatchSnapshot()
    })
  })

  describe('Section Container', () => {
    it('renders the section container', async () => {
      await prepare()

      expect(screen.getByTestId(TAXES_SELECTOR_SECTION_TEST_ID)).toBeInTheDocument()
    })
  })

  describe('Title', () => {
    it('always renders the title', async () => {
      await prepare()

      const title = screen.getByTestId(TAXES_SELECTOR_TITLE_TEST_ID)

      expect(title).toBeInTheDocument()
      expect(title).toHaveTextContent('Taxes')
    })

    it('renders with custom title', async () => {
      await prepare({ title: 'Applied Taxes' })

      const title = screen.getByTestId(TAXES_SELECTOR_TITLE_TEST_ID)

      expect(title).toHaveTextContent('Applied Taxes')
    })
  })

  describe('Description', () => {
    it('does not render description when not provided', async () => {
      await prepare()

      expect(screen.queryByTestId(TAXES_SELECTOR_DESCRIPTION_TEST_ID)).not.toBeInTheDocument()
    })

    it('renders description when provided', async () => {
      await prepare({ description: 'Select applicable taxes' })

      const description = screen.getByTestId(TAXES_SELECTOR_DESCRIPTION_TEST_ID)

      expect(description).toBeInTheDocument()
      expect(description).toHaveTextContent('Select applicable taxes')
    })
  })

  describe('Taxes List', () => {
    it('does not render taxes list when no taxes', async () => {
      await prepare({ taxes: [] })

      expect(screen.queryByTestId(TAXES_SELECTOR_LIST_TEST_ID)).not.toBeInTheDocument()
    })

    it('renders taxes list when taxes are provided', async () => {
      await prepare({ taxes: mockTaxes })

      expect(screen.getByTestId(TAXES_SELECTOR_LIST_TEST_ID)).toBeInTheDocument()
    })

    it('renders tax chips with correct test IDs', async () => {
      await prepare({ taxes: mockTaxes })

      expect(screen.getByTestId(buildTaxChipTestId('tax-1'))).toBeInTheDocument()
      expect(screen.getByTestId(buildTaxChipTestId('tax-2'))).toBeInTheDocument()
    })

    it('renders tax chips with correct labels', async () => {
      await prepare({ taxes: mockTaxes })

      expect(screen.getByTestId(buildTaxChipTestId('tax-1'))).toHaveTextContent('VAT (20%)')
      expect(screen.getByTestId(buildTaxChipTestId('tax-2'))).toHaveTextContent('GST (10%)')
    })
  })

  describe('Add Button', () => {
    it('renders add button initially', async () => {
      await prepare()

      expect(screen.getByTestId(TAXES_SELECTOR_ADD_BUTTON_TEST_ID)).toBeInTheDocument()
    })

    it('renders add button when taxes are present', async () => {
      await prepare({ taxes: mockTaxes })

      expect(screen.getByTestId(TAXES_SELECTOR_ADD_BUTTON_TEST_ID)).toBeInTheDocument()
    })

    it('hides add button when combobox is visible', async () => {
      await prepare()

      expect(screen.getByTestId(TAXES_SELECTOR_ADD_BUTTON_TEST_ID)).toBeInTheDocument()

      await waitFor(() =>
        userEvent.click(screen.getByTestId(TAXES_SELECTOR_ADD_BUTTON_TEST_ID) as HTMLElement),
      )

      expect(screen.queryByTestId(TAXES_SELECTOR_ADD_BUTTON_TEST_ID)).not.toBeInTheDocument()
      expect(screen.getByTestId(TAXES_SELECTOR_COMBOBOX_CONTAINER_TEST_ID)).toBeInTheDocument()
    })

    it('shows combobox container when add button is clicked', async () => {
      await prepare()

      expect(
        screen.queryByTestId(TAXES_SELECTOR_COMBOBOX_CONTAINER_TEST_ID),
      ).not.toBeInTheDocument()

      await waitFor(() =>
        userEvent.click(screen.getByTestId(TAXES_SELECTOR_ADD_BUTTON_TEST_ID) as HTMLElement),
      )

      expect(screen.getByTestId(TAXES_SELECTOR_COMBOBOX_CONTAINER_TEST_ID)).toBeInTheDocument()
    })
  })

  describe('Combobox Container', () => {
    it('does not render combobox container initially', async () => {
      await prepare()

      expect(
        screen.queryByTestId(TAXES_SELECTOR_COMBOBOX_CONTAINER_TEST_ID),
      ).not.toBeInTheDocument()
    })

    it('renders combobox container after clicking add button', async () => {
      await prepare()

      await waitFor(() =>
        userEvent.click(screen.getByTestId(TAXES_SELECTOR_ADD_BUTTON_TEST_ID) as HTMLElement),
      )

      expect(screen.getByTestId(TAXES_SELECTOR_COMBOBOX_CONTAINER_TEST_ID)).toBeInTheDocument()
    })

    it('renders dismiss button when combobox is visible', async () => {
      await prepare()

      await waitFor(() =>
        userEvent.click(screen.getByTestId(TAXES_SELECTOR_ADD_BUTTON_TEST_ID) as HTMLElement),
      )

      expect(screen.getByTestId(TAXES_SELECTOR_DISMISS_BUTTON_TEST_ID)).toBeInTheDocument()
    })

    it('hides combobox container when dismiss button is clicked', async () => {
      await prepare()

      await waitFor(() =>
        userEvent.click(screen.getByTestId(TAXES_SELECTOR_ADD_BUTTON_TEST_ID) as HTMLElement),
      )

      expect(screen.getByTestId(TAXES_SELECTOR_COMBOBOX_CONTAINER_TEST_ID)).toBeInTheDocument()

      await waitFor(() =>
        userEvent.click(screen.getByTestId(TAXES_SELECTOR_DISMISS_BUTTON_TEST_ID) as HTMLElement),
      )

      expect(
        screen.queryByTestId(TAXES_SELECTOR_COMBOBOX_CONTAINER_TEST_ID),
      ).not.toBeInTheDocument()
    })

    it('shows add button again when combobox is dismissed', async () => {
      await prepare()

      await waitFor(() =>
        userEvent.click(screen.getByTestId(TAXES_SELECTOR_ADD_BUTTON_TEST_ID) as HTMLElement),
      )

      expect(screen.queryByTestId(TAXES_SELECTOR_ADD_BUTTON_TEST_ID)).not.toBeInTheDocument()

      await waitFor(() =>
        userEvent.click(screen.getByTestId(TAXES_SELECTOR_DISMISS_BUTTON_TEST_ID) as HTMLElement),
      )

      expect(screen.getByTestId(TAXES_SELECTOR_ADD_BUTTON_TEST_ID)).toBeInTheDocument()
    })
  })

  describe('Tax Chip Deletion', () => {
    it('calls onUpdate when delete icon is clicked on a tax chip', async () => {
      await prepare({ taxes: mockTaxes })

      const taxChip = screen.getByTestId(buildTaxChipTestId('tax-1'))
      // The delete button is a Button component with data-test="button" inside the chip
      const deleteButton = taxChip.querySelector('[data-test="button"]')

      expect(deleteButton).toBeInTheDocument()

      await waitFor(() => userEvent.click(deleteButton as HTMLElement))

      expect(mockOnUpdate).toHaveBeenCalledWith([mockTaxes[1]])
    })

    it('calls onUpdate with empty array when last tax is deleted', async () => {
      const singleTax = [mockTaxes[0]]

      await prepare({ taxes: singleTax })

      const taxChip = screen.getByTestId(buildTaxChipTestId('tax-1'))
      // The delete button is a Button component with data-test="button" inside the chip
      const deleteButton = taxChip.querySelector('[data-test="button"]')

      expect(deleteButton).toBeInTheDocument()

      await waitFor(() => userEvent.click(deleteButton as HTMLElement))

      expect(mockOnUpdate).toHaveBeenCalledWith([])
    })
  })

  describe('buildTaxChipTestId helper', () => {
    it('returns correct test ID format', () => {
      expect(buildTaxChipTestId('tax-123')).toBe('tax-chip-tax-123')
      expect(buildTaxChipTestId('abc')).toBe('tax-chip-abc')
    })
  })
})
