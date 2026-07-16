import { configure, render, screen } from '@testing-library/react'

import { FieldErrorTooltip } from '../FieldErrorTooltip'

configure({ testIdAttribute: 'data-test' })

const mockUseFieldError = jest.fn()

jest.mock('~/hooks/forms/useFieldError', () => ({
  useFieldError: (...args: unknown[]) => mockUseFieldError(...args),
}))

jest.mock('~/components/designSystem/Tooltip', () => ({
  Tooltip: ({
    children,
    title,
    disableHoverListener,
  }: {
    children: React.ReactNode
    title: string
    disableHoverListener: boolean
    placement: string
  }) => (
    <div
      data-test="mock-tooltip"
      data-title={title}
      data-disable-hover={String(disableHoverListener)}
    >
      {children}
    </div>
  ),
}))

describe('FieldErrorTooltip', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN the component mounts', () => {
    describe('WHEN useFieldError is called', () => {
      it('THEN should pass noBoolean and translateErrors options', () => {
        mockUseFieldError.mockReturnValue(undefined)

        render(
          <FieldErrorTooltip>
            <span>child</span>
          </FieldErrorTooltip>,
        )

        expect(mockUseFieldError).toHaveBeenCalledWith({
          noBoolean: true,
          translateErrors: true,
          firstOnly: true,
        })
      })
    })
  })

  describe('GIVEN useFieldError returns an error message', () => {
    describe('WHEN no title prop is provided', () => {
      it('THEN should use the error message as the tooltip title', () => {
        mockUseFieldError.mockReturnValue('Some validation error')

        render(
          <FieldErrorTooltip>
            <span>child</span>
          </FieldErrorTooltip>,
        )

        const tooltip = screen.getByTestId('mock-tooltip')

        expect(tooltip).toHaveAttribute('data-title', 'Some validation error')
      })

      it('THEN should enable hover listener', () => {
        mockUseFieldError.mockReturnValue('Some validation error')

        render(
          <FieldErrorTooltip>
            <span>child</span>
          </FieldErrorTooltip>,
        )

        const tooltip = screen.getByTestId('mock-tooltip')

        expect(tooltip).toHaveAttribute('data-disable-hover', 'false')
      })
    })
  })

  describe('GIVEN a title prop is provided', () => {
    describe('WHEN useFieldError also returns an error', () => {
      it('THEN should use the title prop instead of the error', () => {
        mockUseFieldError.mockReturnValue('Error message')

        render(
          <FieldErrorTooltip title="Custom title">
            <span>child</span>
          </FieldErrorTooltip>,
        )

        const tooltip = screen.getByTestId('mock-tooltip')

        expect(tooltip).toHaveAttribute('data-title', 'Custom title')
      })
    })
  })

  describe('GIVEN useFieldError returns undefined', () => {
    describe('WHEN the component renders', () => {
      it('THEN should disable hover listener', () => {
        mockUseFieldError.mockReturnValue(undefined)

        render(
          <FieldErrorTooltip>
            <span>child</span>
          </FieldErrorTooltip>,
        )

        const tooltip = screen.getByTestId('mock-tooltip')

        expect(tooltip).toHaveAttribute('data-disable-hover', 'true')
      })

      it('THEN should set tooltip title to empty string', () => {
        mockUseFieldError.mockReturnValue(undefined)

        render(
          <FieldErrorTooltip>
            <span>child</span>
          </FieldErrorTooltip>,
        )

        const tooltip = screen.getByTestId('mock-tooltip')

        expect(tooltip).toHaveAttribute('data-title', '')
      })
    })
  })

  describe('GIVEN the component has children', () => {
    describe('WHEN rendered', () => {
      it('THEN should render the children inside the tooltip', () => {
        mockUseFieldError.mockReturnValue(undefined)

        render(
          <FieldErrorTooltip>
            <span data-test="child-element">Hello</span>
          </FieldErrorTooltip>,
        )

        expect(screen.getByTestId('child-element')).toBeInTheDocument()
      })
    })
  })
})
