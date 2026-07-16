import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createRef } from 'react'

import {
  EditBillingEntityDocumentLocaleDialog,
  EditBillingEntityDocumentLocaleDialogRef,
} from '~/components/settings/invoices/EditBillingEntityDocumentLocaleDialog'
import { UpdateDocumentLocaleBillingEntityDocument } from '~/generated/graphql'
import { render, TestMocksType } from '~/test-utils'

jest.mock('@tanstack/react-virtual', () => ({
  useVirtualizer: ({ count }: { count: number }) => ({
    getTotalSize: () => count * 56,
    getVirtualItems: () =>
      Array.from({ length: count }, (_, i) => ({
        index: i,
        key: String(i),
        start: i * 56,
        size: 56,
      })),
    scrollToIndex: jest.fn(),
    measureElement: jest.fn(),
  }),
}))

const BILLING_ENTITY_ID = 'billing-entity-1'

const mockAddToast = jest.fn()

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: (params: unknown) => mockAddToast(params),
}))

const getActionButtons = () => screen.getAllByRole('button').filter((b) => !!b.textContent?.trim())

const openLocaleOption = async (user: ReturnType<typeof userEvent.setup>, label: string) => {
  await user.click(screen.getByRole('combobox'))

  const optionWrapper = await screen.findByTestId(`combobox-item-${label}`)
  const option = optionWrapper.querySelector('.MuiAutocomplete-option') as HTMLElement

  await user.click(option)
}

async function prepare({
  documentLocale = 'en',
  mocks = [],
}: {
  documentLocale?: string
  mocks?: TestMocksType
} = {}) {
  const ref = createRef<EditBillingEntityDocumentLocaleDialogRef>()

  await act(() =>
    render(
      <EditBillingEntityDocumentLocaleDialog
        ref={ref}
        id={BILLING_ENTITY_ID}
        documentLocale={documentLocale}
      />,
      { mocks },
    ),
  )

  await act(() => {
    ref.current?.openDialog()
  })

  return { ref }
}

describe('EditBillingEntityDocumentLocaleDialog', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('GIVEN the dialog ref API', () => {
    describe('WHEN openDialog is called', () => {
      it('THEN should show the dialog', async () => {
        const ref = createRef<EditBillingEntityDocumentLocaleDialogRef>()

        await act(() =>
          render(
            <EditBillingEntityDocumentLocaleDialog
              ref={ref}
              id={BILLING_ENTITY_ID}
              documentLocale="en"
            />,
          ),
        )

        expect(screen.queryByTestId('dialog-title')).not.toBeInTheDocument()

        await act(() => {
          ref.current?.openDialog()
        })

        await waitFor(() => {
          expect(screen.getByTestId('dialog-title')).toBeInTheDocument()
        })
      })
    })

    describe('WHEN closeDialog is called', () => {
      it('THEN should hide the dialog', async () => {
        const { ref } = await prepare()

        expect(screen.getByTestId('dialog-title')).toBeInTheDocument()

        await act(() => {
          ref.current?.closeDialog()
        })

        await waitFor(() => {
          expect(screen.queryByTestId('dialog-title')).not.toBeInTheDocument()
        })
      })
    })
  })

  describe('GIVEN the dialog is opened', () => {
    describe('WHEN rendered with a documentLocale prop', () => {
      it.each([
        ['title', 'dialog-title'],
        ['description', 'dialog-description'],
      ])('THEN should display the %s', async (_, testId) => {
        await prepare()

        expect(screen.getByTestId(testId)).toBeInTheDocument()
      })

      it('THEN should render cancel and submit action buttons', async () => {
        await prepare()

        expect(getActionButtons()).toHaveLength(2)
      })

      it.each([
        ['en', 'English'],
        ['fr', 'French'],
        ['de', 'German'],
      ])(
        'THEN should pre-fill the combobox with the %s locale label',
        async (locale, expectedLabel) => {
          await prepare({ documentLocale: locale })

          const combobox = screen.getByRole('combobox') as HTMLInputElement

          expect(combobox.value).toBe(expectedLabel)
        },
      )
    })
  })

  describe('GIVEN the form validation', () => {
    describe('WHEN the form is pristine', () => {
      it('THEN should disable the submit button', async () => {
        await prepare()

        const [, submitButton] = getActionButtons()

        expect(submitButton).toBeDisabled()
      })
    })

    describe('WHEN the user selects a different locale', () => {
      it('THEN should enable the submit button', async () => {
        const user = userEvent.setup()

        await prepare({ documentLocale: 'en' })

        await openLocaleOption(user, 'French')

        await waitFor(() => {
          const [, submitButton] = getActionButtons()

          expect(submitButton).not.toBeDisabled()
        })
      })
    })
  })

  describe('GIVEN the form submission', () => {
    const buildMutationMock = (resultFn?: jest.Mock) => ({
      request: {
        query: UpdateDocumentLocaleBillingEntityDocument,
        variables: {
          input: {
            id: BILLING_ENTITY_ID,
            billingConfiguration: {
              documentLocale: 'fr',
            },
          },
        },
      },
      result:
        resultFn ??
        (() => ({
          data: {
            updateBillingEntity: {
              id: BILLING_ENTITY_ID,
              billingConfiguration: {
                id: 'billing-config-1',
                documentLocale: 'fr',
              },
            },
          },
        })),
    })

    describe('WHEN the user submits a new locale', () => {
      it('THEN should call the mutation with id and billingConfiguration', async () => {
        const user = userEvent.setup()
        const mutationResult = jest.fn(() => ({
          data: {
            updateBillingEntity: {
              id: BILLING_ENTITY_ID,
              billingConfiguration: {
                id: 'billing-config-1',
                documentLocale: 'fr',
              },
            },
          },
        }))

        await prepare({
          documentLocale: 'en',
          mocks: [buildMutationMock(mutationResult)],
        })

        await openLocaleOption(user, 'French')

        const [, submitButton] = getActionButtons()

        await user.click(submitButton)

        await waitFor(() => {
          expect(mutationResult).toHaveBeenCalled()
        })
      })

      it('THEN should show a success toast', async () => {
        const user = userEvent.setup()

        await prepare({
          documentLocale: 'en',
          mocks: [buildMutationMock()],
        })

        await openLocaleOption(user, 'French')

        const [, submitButton] = getActionButtons()

        await user.click(submitButton)

        await waitFor(() => {
          expect(mockAddToast).toHaveBeenCalledWith(
            expect.objectContaining({ severity: 'success' }),
          )
        })
      })

      it('THEN should close the dialog after a successful submission', async () => {
        const user = userEvent.setup()

        await prepare({
          documentLocale: 'en',
          mocks: [buildMutationMock()],
        })

        await openLocaleOption(user, 'French')

        const [, submitButton] = getActionButtons()

        await user.click(submitButton)

        await waitFor(() => {
          expect(screen.queryByTestId('dialog-title')).not.toBeInTheDocument()
        })
      })
    })
  })

  describe('GIVEN the dialog actions', () => {
    describe('WHEN the cancel button is clicked', () => {
      it('THEN should close the dialog without calling the mutation', async () => {
        const user = userEvent.setup()

        await prepare()

        expect(screen.getByTestId('dialog-title')).toBeInTheDocument()

        const [cancelButton] = getActionButtons()

        await user.click(cancelButton)

        await waitFor(() => {
          expect(screen.queryByTestId('dialog-title')).not.toBeInTheDocument()
        })

        expect(mockAddToast).not.toHaveBeenCalled()
      })
    })

    describe('WHEN the dialog is closed and reopened', () => {
      it('THEN should reset the form to its initial value', async () => {
        const user = userEvent.setup()
        const { ref } = await prepare({ documentLocale: 'en' })

        await openLocaleOption(user, 'French')

        await waitFor(() => {
          const [, submitButton] = getActionButtons()

          expect(submitButton).not.toBeDisabled()
        })

        await act(() => {
          ref.current?.closeDialog()
        })

        await waitFor(() => {
          expect(screen.queryByTestId('dialog-title')).not.toBeInTheDocument()
        })

        await act(() => {
          ref.current?.openDialog()
        })

        await waitFor(() => {
          const combobox = screen.getByRole('combobox') as HTMLInputElement

          expect(combobox.value).toBe('English')
        })

        const [, submitButton] = getActionButtons()

        expect(submitButton).toBeDisabled()
      })
    })
  })
})
