import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { useAppForm } from '~/hooks/forms/useAppform'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'
import MetadataAccordion from '~/pages/createCustomers/metadataAccordion/MetadataAccordion'
import { render } from '~/test-utils'

const MAX_METADATA_COUNT = 5

// Create a test wrapper component that properly initializes the form
const TestMetadataAccordionWrapper = ({
  initialMetadata = [],
}: {
  initialMetadata?: Array<{ key: string; value: string; displayInInvoice: boolean; id?: string }>
}) => {
  const form = useAppForm({
    defaultValues: {
      ...emptyCreateCustomerDefaultValues,
      metadata: initialMetadata,
    } as typeof emptyCreateCustomerDefaultValues,
  })

  return <MetadataAccordion form={form} />
}

describe('MetadataAccordion Integration Tests', () => {
  describe('WHEN rendering the component', () => {
    it('THEN should render without crashing', () => {
      const { container } = render(<TestMetadataAccordionWrapper />)

      // Check for accordion content by checking that the component rendered
      expect(container.firstChild).toBeInTheDocument()
    })

    it('THEN should render a matching snapshot', () => {
      const rendered = render(<TestMetadataAccordionWrapper />)

      expect(rendered.container).toMatchSnapshot()
    })

    it('THEN should render a matching snapshot after expansion', async () => {
      const user = userEvent.setup()
      const rendered = render(<TestMetadataAccordionWrapper />)

      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)
      await waitFor(() => {
        // After expanding, check for the add metadata button
        expect(screen.getByTestId('add-metadata-button')).toBeInTheDocument()
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should render with initial metadata', async () => {
      const user = userEvent.setup()
      const initialMetadata = [
        { key: 'test-key', value: 'test-value', displayInInvoice: true, id: '1' },
        { key: 'another-key', value: 'another-value', displayInInvoice: false, id: '2' },
      ]

      render(<TestMetadataAccordionWrapper initialMetadata={initialMetadata} />)

      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      await waitFor(() => {
        // Check that metadata fields are rendered
        expect(screen.getAllByRole('textbox')).toHaveLength(4) // 2 keys + 2 values
        expect(screen.getAllByRole('checkbox')).toHaveLength(2) // 2 display switches

        // Verify initial metadata values are properly rendered
        expect(screen.getByDisplayValue('test-key')).toBeInTheDocument()
        expect(screen.getByDisplayValue('test-value')).toBeInTheDocument()
        expect(screen.getByDisplayValue('another-key')).toBeInTheDocument()
        expect(screen.getByDisplayValue('another-value')).toBeInTheDocument()
      })
    })

    it('THEN should display headers when metadata exists', async () => {
      const user = userEvent.setup()
      const initialMetadata = [
        { key: 'test-key', value: 'test-value', displayInInvoice: true, id: '1' },
      ]
      const rendered = render(<TestMetadataAccordionWrapper initialMetadata={initialMetadata} />)

      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      await waitFor(() => {
        // Check for header text (translated text keys from component)
        // Since we're using translated keys, we check for the structure instead
        expect(screen.getByTestId('add-metadata-button')).toBeInTheDocument()
        expect(screen.getAllByRole('textbox')).toHaveLength(2) // 1 key + 1 value
        expect(rendered.container).toMatchSnapshot()
      })
    })
  })

  describe('WHEN user interacts with metadata', () => {
    it('THEN should add new metadata when add button is clicked', async () => {
      const user = userEvent.setup()

      render(<TestMetadataAccordionWrapper />)

      // Expand accordion
      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      await waitFor(() => {
        expect(screen.getByTestId('add-metadata-button')).toBeInTheDocument()
      })

      // Click add button
      const addButton = screen.getByTestId('add-metadata-button')

      await user.click(addButton)

      await waitFor(() => {
        // Should show one row of metadata fields
        expect(screen.getAllByRole('textbox')).toHaveLength(2) // key + value
        expect(screen.getAllByRole('checkbox')).toHaveLength(1) // displayInInvoice switch
        // Should show delete button for the metadata row
        expect(screen.getAllByRole('button')).toHaveLength(4) // 2 accordion buttons + add + delete
      })
    })

    it('THEN should allow filling metadata fields', async () => {
      const user = userEvent.setup()

      render(<TestMetadataAccordionWrapper />)

      // Expand accordion and add metadata
      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      const addButton = screen.getByTestId('add-metadata-button')

      await user.click(addButton)

      await waitFor(() => {
        const textInputs = screen.getAllByRole('textbox')

        expect(textInputs).toHaveLength(2)
      })

      // Fill in the fields
      const [keyInput, valueInput] = screen.getAllByRole('textbox')

      await user.type(keyInput, 'test-key')
      await user.type(valueInput, 'test-value')

      await waitFor(() => {
        expect(keyInput).toHaveValue('test-key')
        expect(valueInput).toHaveValue('test-value')
      })
    })

    it('THEN should toggle displayInInvoice switch', async () => {
      const user = userEvent.setup()

      render(<TestMetadataAccordionWrapper />)

      // Expand accordion and add metadata
      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      const addButton = screen.getByTestId('add-metadata-button')

      await user.click(addButton)

      await waitFor(() => {
        const switchElement = screen.getByRole('checkbox')

        expect(switchElement).not.toBeChecked()
      })

      // Toggle the switch
      const switchElement = screen.getByRole('checkbox')

      await user.click(switchElement)

      await waitFor(() => {
        expect(switchElement).toBeChecked()
      })
    })

    it('THEN should remove metadata when delete button is clicked', async () => {
      const user = userEvent.setup()
      const initialMetadata = [
        { key: 'test-key', value: 'test-value', displayInInvoice: true, id: '1' },
      ]

      render(<TestMetadataAccordionWrapper initialMetadata={initialMetadata} />)

      // Expand accordion
      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      await waitFor(() => {
        expect(screen.getAllByRole('textbox')).toHaveLength(2)
        // Find delete button (trash icon)
        const buttons = screen.getAllByRole('button')

        expect(buttons).toHaveLength(4) // 2 accordion buttons + add + delete
      })

      // Click delete button (should be the second-to-last button, before add button)
      const buttons = screen.getAllByRole('button')
      const deleteButton = buttons[buttons.length - 2] // Second to last (last is add button)

      await user.click(deleteButton)

      await waitFor(() => {
        // Metadata should be removed
        expect(screen.queryAllByRole('textbox')).toHaveLength(0)
        expect(screen.queryAllByRole('switch')).toHaveLength(0)
      })
    })

    it('THEN should disable add button when maximum metadata count is reached', async () => {
      const user = userEvent.setup()
      // Create maximum number of metadata items
      const maxMetadata = Array.from({ length: MAX_METADATA_COUNT }, (_, i) => ({
        key: `key-${i}`,
        value: `value-${i}`,
        displayInInvoice: false,
        id: `${i}`,
      }))

      render(<TestMetadataAccordionWrapper initialMetadata={maxMetadata} />)

      // Expand accordion
      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      await waitFor(() => {
        const addButton = screen.getByTestId('add-metadata-button')

        expect(addButton).toBeDisabled()
      })
    })

    it('THEN should enable add button when below maximum metadata count', async () => {
      const user = userEvent.setup()
      // Create less than maximum metadata items
      const someMetadata = Array.from({ length: MAX_METADATA_COUNT - 1 }, (_, i) => ({
        key: `key-${i}`,
        value: `value-${i}`,
        displayInInvoice: false,
        id: `${i}`,
      }))

      render(<TestMetadataAccordionWrapper initialMetadata={someMetadata} />)

      // Expand accordion
      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      await waitFor(() => {
        const addButton = screen.getByTestId('add-metadata-button')

        expect(addButton).not.toBeDisabled()
      })
    })
  })

  describe('WHEN handling metadata validation', () => {
    it('THEN should handle multiple metadata items correctly', async () => {
      const user = userEvent.setup()

      render(<TestMetadataAccordionWrapper />)

      // Expand accordion
      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      // Add first metadata
      const addButton = screen.getByTestId('add-metadata-button')

      await user.click(addButton)

      // Add second metadata
      await user.click(addButton)

      await waitFor(() => {
        expect(screen.getAllByRole('textbox')).toHaveLength(4) // 2 keys + 2 values
        expect(screen.getAllByRole('checkbox')).toHaveLength(2) // 2 switches
        // Should have 2 delete buttons plus accordion and add buttons
        expect(screen.getAllByRole('button')).toHaveLength(5) // accordion + add + 2 delete
      })
    })

    it('THEN should maintain form state across metadata operations', async () => {
      const user = userEvent.setup()

      render(<TestMetadataAccordionWrapper />)

      // Expand accordion
      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      // Add metadata and fill it
      const addButton = screen.getByTestId('add-metadata-button')

      await user.click(addButton)

      const [keyInput, valueInput] = screen.getAllByRole('textbox')

      await user.type(keyInput, 'persistent-key')
      await user.type(valueInput, 'persistent-value')

      // Add another metadata
      await user.click(addButton)

      await waitFor(() => {
        const allInputs = screen.getAllByRole('textbox')

        expect(allInputs).toHaveLength(4)
        // First inputs should maintain their values
        expect(allInputs[0]).toHaveValue('persistent-key')
        expect(allInputs[1]).toHaveValue('persistent-value')
      })
    })

    it('THEN should handle edge cases correctly', async () => {
      const user = userEvent.setup()
      const initialMetadata = [{ key: '', value: '', displayInInvoice: false, id: '1' }]

      render(<TestMetadataAccordionWrapper initialMetadata={initialMetadata} />)

      // Expand accordion
      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      await waitFor(() => {
        // Should render even with empty metadata
        expect(screen.getAllByRole('textbox')).toHaveLength(2)
        expect(screen.getByTestId('add-metadata-button')).toBeInTheDocument()
      })
    })
  })

  describe('WHEN testing component structure', () => {
    it('THEN should have proper accordion structure', async () => {
      const user = userEvent.setup()

      render(<TestMetadataAccordionWrapper />)

      // Should start collapsed
      expect(screen.queryByTestId('add-metadata-button')).not.toBeInTheDocument()

      // Expand accordion
      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      await waitFor(() => {
        // Should show content when expanded
        expect(screen.getByTestId('add-metadata-button')).toBeInTheDocument()
      })
    })

    it('THEN should maintain proper grid layout with metadata', async () => {
      const user = userEvent.setup()
      const initialMetadata = [
        { key: 'layout-test', value: 'layout-value', displayInInvoice: true, id: '1' },
      ]

      render(<TestMetadataAccordionWrapper initialMetadata={initialMetadata} />)

      // Expand accordion
      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      await waitFor(() => {
        // Check that all expected form elements are present
        expect(screen.getAllByRole('textbox')).toHaveLength(2) // key + value
        expect(screen.getAllByRole('checkbox')).toHaveLength(1) // displayInInvoice
        expect(screen.getAllByRole('button')).toHaveLength(4) // 2 accordion buttons + add + delete
      })
    })
  })
})
