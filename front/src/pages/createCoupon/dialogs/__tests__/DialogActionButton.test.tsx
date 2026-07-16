import { act, screen } from '@testing-library/react'

import { render } from '~/test-utils'

import { DialogActionButton, useSetDisabledRef } from '../DialogActionButton'

const SUBMIT_BUTTON_TEST_ID = 'submit-button'
const DEFAULT_LABEL = 'Submit'

const TestWrapper = ({
  label = DEFAULT_LABEL,
  dataTest = SUBMIT_BUTTON_TEST_ID,
}: {
  label?: string
  dataTest?: string
}) => {
  const setDisabledRef = useSetDisabledRef()

  return (
    <>
      <DialogActionButton label={label} setDisabledRef={setDisabledRef} data-test={dataTest} />
      <button
        data-test="toggle-enabled"
        onClick={() => setDisabledRef.current(false)}
        type="button"
      >
        Enable
      </button>
      <button
        data-test="toggle-disabled"
        onClick={() => setDisabledRef.current(true)}
        type="button"
      >
        Disable
      </button>
    </>
  )
}

describe('DialogActionButton', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the component is rendered', () => {
    describe('WHEN in default state', () => {
      it('THEN should render a disabled submit button', () => {
        render(<TestWrapper />)

        const button = screen.getByTestId(SUBMIT_BUTTON_TEST_ID)

        expect(button).toBeInTheDocument()
        expect(button).toBeDisabled()
        expect(button).toHaveAttribute('type', 'submit')
      })

      it('THEN should display the provided label', () => {
        render(<TestWrapper label="Add item" />)

        const button = screen.getByTestId(SUBMIT_BUTTON_TEST_ID)

        expect(button).toHaveTextContent('Add item')
      })

      it('THEN should apply the data-test attribute', () => {
        render(<TestWrapper dataTest="custom-test-id" />)

        expect(screen.getByTestId('custom-test-id')).toBeInTheDocument()
      })
    })

    describe('WHEN setDisabledRef is called with false', () => {
      it('THEN should enable the button', async () => {
        render(<TestWrapper />)

        const button = screen.getByTestId(SUBMIT_BUTTON_TEST_ID)

        expect(button).toBeDisabled()

        await act(async () => {
          screen.getByTestId('toggle-enabled').click()
        })

        expect(button).not.toBeDisabled()
      })
    })

    describe('WHEN setDisabledRef is toggled back to disabled', () => {
      it('THEN should disable the button again', async () => {
        render(<TestWrapper />)

        const button = screen.getByTestId(SUBMIT_BUTTON_TEST_ID)

        await act(async () => {
          screen.getByTestId('toggle-enabled').click()
        })

        expect(button).not.toBeDisabled()

        await act(async () => {
          screen.getByTestId('toggle-disabled').click()
        })

        expect(button).toBeDisabled()
      })
    })
  })
})
