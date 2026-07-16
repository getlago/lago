import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createRef } from 'react'

import {
  ROTATE_API_KEY_DIALOG_SUBMIT_BUTTON_TEST_ID,
  RotateApiKeyDialog,
  RotateApiKeyDialogRef,
} from '~/components/developers/apiKeys/RotateApiKeyDialog'
import { ApiKeyForRotateApiKeyDialogFragment } from '~/generated/graphql'
import { render } from '~/test-utils'

const mockRotate = jest.fn()

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({ isPremium: true }),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useRotateApiKeyMutation: () => [mockRotate],
}))

const apiKey: ApiKeyForRotateApiKeyDialogFragment = {
  __typename: 'SanitizedApiKey',
  id: 'api-key-1',
  name: 'My API Key',
  lastUsedAt: null,
}

async function prepare() {
  const ref = createRef<RotateApiKeyDialogRef>()

  await act(() => render(<RotateApiKeyDialog ref={ref} openPremiumDialog={jest.fn()} />))

  await act(() => {
    ref.current?.openDialog({ apiKey, callBack: jest.fn() })
  })

  await waitFor(() => {
    expect(screen.getByTestId('dialog-title')).toBeInTheDocument()
  })

  return { ref }
}

describe('RotateApiKeyDialog', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('GIVEN the "Now" (immediate) expiration option', () => {
    describe('WHEN the user submits the form', () => {
      it('THEN it rotates the key with a null expiresAt', async () => {
        const user = userEvent.setup()

        await prepare()

        // "Now" is the default selected option, no need to click any radio.
        await act(async () => {
          await user.click(screen.getByTestId(ROTATE_API_KEY_DIALOG_SUBMIT_BUTTON_TEST_ID))
        })

        await waitFor(() => {
          expect(mockRotate).toHaveBeenCalledWith({
            variables: {
              input: {
                id: 'api-key-1',
                expiresAt: null,
                name: 'My API Key',
              },
            },
          })
        })
      })
    })
  })

  describe('GIVEN a future expiration option (One week)', () => {
    describe('WHEN the user submits the form', () => {
      it('THEN it rotates the key with a non-null ISO expiresAt', async () => {
        const user = userEvent.setup()

        await prepare()

        const oneWeekRadio = screen
          .getAllByRole('radio')
          .find((radio) => radio.getAttribute('value') === 'OneWeek')

        expect(oneWeekRadio).toBeDefined()

        await act(async () => {
          await user.click(oneWeekRadio as HTMLElement)
        })

        await act(async () => {
          await user.click(screen.getByTestId(ROTATE_API_KEY_DIALOG_SUBMIT_BUTTON_TEST_ID))
        })

        await waitFor(() => {
          expect(mockRotate).toHaveBeenCalledTimes(1)
        })

        const submittedExpiresAt = mockRotate.mock.calls[0][0].variables.input.expiresAt

        expect(submittedExpiresAt).not.toBeNull()
        expect(typeof submittedExpiresAt).toBe('string')
      })
    })
  })
})
