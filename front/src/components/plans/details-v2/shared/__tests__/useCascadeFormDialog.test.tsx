import NiceModal from '@ebay/nice-modal-react'
import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactNode } from 'react'

import { FORM_DIALOG_NAME } from '~/components/dialogs/const'
import FormDialog from '~/components/dialogs/FormDialog'
import { render } from '~/test-utils'

import { useCascadeFormDialog } from '../useCascadeFormDialog'

NiceModal.register(FORM_DIALOG_NAME, FormDialog)

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const NiceModalWrapper = ({ children }: { children: ReactNode }) => (
  <NiceModal.Provider>{children}</NiceModal.Provider>
)

type HarnessProps = {
  hasOverriddenPlans: boolean
  onConfirm: (v: boolean) => Promise<void> | void
}

const Harness = ({ hasOverriddenPlans, onConfirm }: HarnessProps) => {
  const { openCascadeDialog } = useCascadeFormDialog()

  return (
    <button
      data-test="open-cascade"
      onClick={() =>
        openCascadeDialog({
          title: 'cascade-title',
          mainActionLabel: 'save-edits',
          hasOverriddenPlans,
          onConfirm,
        })
      }
    >
      open
    </button>
  )
}

describe('useCascadeFormDialog', () => {
  afterEach(() => {
    cleanup()
  })

  it('short-circuits to onConfirm(false) when plan has no children', async () => {
    const onConfirm = jest.fn()

    render(
      <NiceModalWrapper>
        <Harness hasOverriddenPlans={false} onConfirm={onConfirm} />
      </NiceModalWrapper>,
    )

    await act(async () => {
      await userEvent.click(screen.getByTestId('open-cascade'))
    })

    expect(onConfirm).toHaveBeenCalledWith(false)
    expect(screen.queryByText('cascade-title')).not.toBeInTheDocument()
  })

  it('opens the dialog when plan has children and submits the default value (true)', async () => {
    const onConfirm = jest.fn()

    render(
      <NiceModalWrapper>
        <Harness hasOverriddenPlans={true} onConfirm={onConfirm} />
      </NiceModalWrapper>,
    )

    await act(async () => {
      await userEvent.click(screen.getByTestId('open-cascade'))
    })

    await waitFor(() => expect(screen.getByText('cascade-title')).toBeInTheDocument())

    // CascadeUpdatesField renders the toggle label + sub-label from translation keys
    expect(screen.getByText('text_1779289915866s3gisblcite')).toBeInTheDocument()
    expect(screen.getByText('text_1779289915866itrqeyj7658')).toBeInTheDocument()

    await act(async () => {
      await userEvent.click(screen.getByRole('button', { name: /save-edits/i }))
    })

    await waitFor(() => expect(onConfirm).toHaveBeenCalledWith(true))
  })

  it('passes the toggled value when the user flips the switch off', async () => {
    const onConfirm = jest.fn()

    render(
      <NiceModalWrapper>
        <Harness hasOverriddenPlans={true} onConfirm={onConfirm} />
      </NiceModalWrapper>,
    )

    await act(async () => {
      await userEvent.click(screen.getByTestId('open-cascade'))
    })

    const toggle = await screen.findByRole('checkbox', { name: 'cascadeUpdates' })

    await act(async () => {
      await userEvent.click(toggle)
      await userEvent.click(screen.getByRole('button', { name: /save-edits/i }))
    })

    await waitFor(() => expect(onConfirm).toHaveBeenCalledWith(false))
  })
})
