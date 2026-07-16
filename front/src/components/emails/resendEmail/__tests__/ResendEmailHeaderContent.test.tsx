import { act, cleanup, screen } from '@testing-library/react'

import { useAppForm } from '~/hooks/forms/useAppform'
import { render } from '~/test-utils'

import {
  resendEmailFormDefaultValues,
  ResendEmailFormDefaultValues,
  resendEmailFormValidationSchema,
} from '../formInitialization'
import ResendEmailHeaderContent from '../ResendEmailHeaderContent'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const ResendEmailHeaderContentWrapper = ({ subject = 'Test Subject' }: { subject?: string }) => {
  const form = useAppForm({
    defaultValues: resendEmailFormDefaultValues as ResendEmailFormDefaultValues,
    validators: {
      onChange: resendEmailFormValidationSchema,
    },
  })

  return (
    <form.AppForm>
      <ResendEmailHeaderContent form={form} subject={subject} />
    </form.AppForm>
  )
}

describe('ResendEmailHeaderContent', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('GIVEN the form initialization', () => {
    describe('WHEN default values are checked', () => {
      it('THEN should have the correct default structure', () => {
        expect(resendEmailFormDefaultValues).toEqual({
          to: [],
          cc: undefined,
          bcc: undefined,
        })
      })
    })

    describe('WHEN validation schema is checked', () => {
      it('THEN should be defined', () => {
        expect(resendEmailFormValidationSchema).toBeDefined()
      })
    })
  })

  describe('GIVEN the component is rendered', () => {
    describe('WHEN rendered with a subject', () => {
      it('THEN should render the subject text', async () => {
        await act(() => render(<ResendEmailHeaderContentWrapper subject="My Email Subject" />))

        expect(screen.getByText('My Email Subject')).toBeInTheDocument()
      })

      it('THEN should render the grid layout', async () => {
        const { container } = await act(() =>
          render(<ResendEmailHeaderContentWrapper subject="My Email Subject" />),
        )

        const gridContainer = container.querySelector('.grid')

        expect(gridContainer).toBeInTheDocument()
      })
    })

    describe('WHEN rendered', () => {
      it('THEN should render four label areas in the grid', async () => {
        const { container } = await act(() => render(<ResendEmailHeaderContentWrapper />))

        // The grid has 4 rows (to, cc, bcc, subject) × 2 columns = 8 direct children
        const gridContainer = container.querySelector('.grid')

        expect(gridContainer).toBeInTheDocument()
        // 4 label Typography + 3 MultipleComboBoxField + 1 subject Typography = 8 children
        expect(gridContainer?.children.length).toBe(8)
      })

      it('THEN should render three combobox fields for to, cc, and bcc', async () => {
        const { container } = await act(() => render(<ResendEmailHeaderContentWrapper />))

        // Each MultipleComboBoxField renders an input, so we should have 3 inputs
        const inputs = container.querySelectorAll('input')

        expect(inputs.length).toBe(3)
      })
    })
  })
})
