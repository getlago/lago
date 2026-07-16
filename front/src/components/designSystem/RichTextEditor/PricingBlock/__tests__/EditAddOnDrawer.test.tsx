import { screen } from '@testing-library/react'

import { render } from '~/test-utils'

import EditAddOnDrawer, { editAddOnDrawerDefaultValues } from '../EditAddOnDrawer'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    organization: { id: 'org-1', timezone: 'UTC' },
  }),
}))

const renderWithForm = (initialValues?: Partial<typeof editAddOnDrawerDefaultValues>) => {
  const { useAppForm: useAppFormHook } = jest.requireActual('~/hooks/forms/useAppform')

  const Wrapper = () => {
    const form = useAppFormHook({
      defaultValues: {
        ...editAddOnDrawerDefaultValues,
        ...initialValues,
      },
    })

    return <EditAddOnDrawer form={form} />
  }

  return render(<Wrapper />)
}

describe('EditAddOnDrawer', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the component is rendered with default values', () => {
    describe('WHEN no initial values are provided', () => {
      it('THEN should render without errors', () => {
        const { container } = renderWithForm()

        expect(container).toBeInTheDocument()
      })

      it('THEN should render section headings', () => {
        renderWithForm()

        // Main heading and description
        const headings = screen.getAllByText(/^text_/)

        expect(headings.length).toBeGreaterThanOrEqual(2)
      })

      it.each([
        { name: 'fromDatetime', label: 'text_1779980717322k58g8b65e2i' },
        { name: 'toDatetime', label: 'text_1779980717322igk4qqvn301' },
      ])('THEN should render the $name date picker field', ({ label }) => {
        renderWithForm()

        expect(screen.getByText(label)).toBeInTheDocument()
      })

      it('THEN should render the invoiceDisplayName text input field', () => {
        renderWithForm()

        // The label for invoice display name
        expect(screen.getByText('text_1780302522400gadrdaf1b98')).toBeInTheDocument()
      })

      it('THEN should render the description text input field', () => {
        renderWithForm()

        // The label for description
        expect(screen.getByText('text_6453819268763979024ad011')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the component renders all form fields', () => {
    describe('WHEN the form is displayed', () => {
      it('THEN should render all 4 form fields', () => {
        renderWithForm()

        // Two date picker labels
        expect(screen.getByText('text_1779980717322k58g8b65e2i')).toBeInTheDocument()
        expect(screen.getByText('text_1779980717322igk4qqvn301')).toBeInTheDocument()
        // Invoice display name label
        expect(screen.getByText('text_1780302522400gadrdaf1b98')).toBeInTheDocument()
        // Description label
        expect(screen.getByText('text_6453819268763979024ad011')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the component renders typography sections', () => {
    describe('WHEN the form is displayed', () => {
      it('THEN should render the billing period section heading and caption', () => {
        renderWithForm()

        expect(screen.getByText('text_17803025224002y9fcnkkbgr')).toBeInTheDocument()
        expect(screen.getByText('text_1780302522400pnacismclbw')).toBeInTheDocument()
      })

      it('THEN should render the display information section heading and caption', () => {
        renderWithForm()

        expect(screen.getByText('text_1780302522400k2n947rez9j')).toBeInTheDocument()
        expect(screen.getByText('text_17803025224002dj16pqxyw2')).toBeInTheDocument()
      })

      it('THEN should render the main drawer heading and description', () => {
        renderWithForm()

        expect(screen.getByText('text_1780302522400cvm8js8nfg2')).toBeInTheDocument()
        expect(screen.getByText('text_17800447462496abqig1cu57')).toBeInTheDocument()
      })

      it('THEN should render the description character limit caption', () => {
        renderWithForm()

        expect(screen.getByText('text_1780302661071iqcpu91vg0u')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the description field configuration', () => {
    describe('WHEN the description field is rendered', () => {
      it('THEN should render as a multiline textarea', () => {
        renderWithForm()

        const textareas = document.querySelectorAll('textarea')

        // At least one textarea should exist (the description field is multiline)
        expect(textareas.length).toBeGreaterThanOrEqual(1)
      })

      it('THEN should have maxLength of 255', () => {
        renderWithForm()

        const textareas = document.querySelectorAll('textarea')
        const descriptionTextarea = Array.from(textareas).find(
          (textarea) => (textarea as HTMLTextAreaElement).maxLength === 255,
        ) as HTMLTextAreaElement

        expect(descriptionTextarea).toBeDefined()
        expect(descriptionTextarea.maxLength).toBe(255)
      })
    })
  })

  describe('GIVEN the component is rendered with pre-filled values', () => {
    describe('WHEN initial values are provided', () => {
      it('THEN should render the invoiceDisplayName with the provided value', () => {
        renderWithForm({
          invoiceDisplayName: 'Custom Display Name',
        })

        const inputs = document.querySelectorAll('input')
        const invoiceInput = Array.from(inputs).find(
          (input) => (input as HTMLInputElement).value === 'Custom Display Name',
        ) as HTMLInputElement

        expect(invoiceInput).toBeDefined()
        expect(invoiceInput.value).toBe('Custom Display Name')
      })

      it('THEN should render the description with the provided value', () => {
        renderWithForm({
          description: 'A test description for the add-on',
        })

        const textareas = document.querySelectorAll('textarea')
        const descriptionTextarea = Array.from(textareas).find(
          (textarea) =>
            (textarea as HTMLTextAreaElement).value === 'A test description for the add-on',
        ) as HTMLTextAreaElement

        expect(descriptionTextarea).toBeDefined()
        expect(descriptionTextarea.value).toBe('A test description for the add-on')
      })
    })
  })

  describe('GIVEN the layout structure', () => {
    describe('WHEN the component is rendered', () => {
      it('THEN should render the billing period section with a bottom shadow separator', () => {
        renderWithForm()

        // The billing period section has shadow-b class for visual separation
        const shadowSection = document.querySelector('.shadow-b')

        expect(shadowSection).toBeInTheDocument()
      })

      it('THEN should render date pickers in a two-column grid', () => {
        renderWithForm()

        const gridContainer = document.querySelector('.grid-cols-2')

        expect(gridContainer).toBeInTheDocument()

        // Both date picker labels should be within the grid
        const fromLabel = screen.getByText('text_1779980717322k58g8b65e2i')
        const toLabel = screen.getByText('text_1779980717322igk4qqvn301')

        expect(gridContainer).toContainElement(fromLabel)
        expect(gridContainer).toContainElement(toLabel)
      })
    })
  })
})
