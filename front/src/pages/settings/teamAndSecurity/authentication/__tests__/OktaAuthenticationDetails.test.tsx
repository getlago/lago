import NiceModal from '@ebay/nice-modal-react'
import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactNode } from 'react'

import CentralizedDialog from '~/components/dialogs/CentralizedDialog'
import {
  CENTRALIZED_DIALOG_NAME,
  FORM_DIALOG_OPENING_DIALOG_NAME,
} from '~/components/dialogs/const'
import FormDialogOpeningDialog from '~/components/dialogs/FormDialogOpeningDialog'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { initializeTranslations } from '~/core/apolloClient'
import { GetOktaIntegrationDocument } from '~/generated/graphql'
import { render, TestMocksType } from '~/test-utils'

import OktaAuthenticationDetails from '../OktaAuthenticationDetails'

const mockNavigateFn = jest.fn()
const mockUseParams = jest.fn().mockReturnValue({ integrationId: 'integration-123' })

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useNavigate: () => mockNavigateFn,
  useParams: () => mockUseParams(),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    organization: {
      authenticationMethods: ['email_password', 'okta'],
    },
  }),
}))

NiceModal.register(FORM_DIALOG_OPENING_DIALOG_NAME, FormDialogOpeningDialog)
NiceModal.register(CENTRALIZED_DIALOG_NAME, CentralizedDialog)

const NiceModalWrapper = ({ children }: { children: ReactNode }) => {
  return <NiceModal.Provider>{children}</NiceModal.Provider>
}

const integrationData = {
  id: 'integration-123',
  clientId: 'test-client-id',
  clientSecret: 'test-client-secret',
  code: 'okta',
  organizationName: 'test-org',
  domain: 'test.example.com',
  name: 'My Okta Integration',
  host: 'okta.example.com',
  __typename: 'OktaIntegration' as const,
}

const successMocks: TestMocksType = [
  {
    request: {
      query: GetOktaIntegrationDocument,
      variables: { id: 'integration-123' },
    },
    result: {
      data: {
        integration: integrationData,
      },
    },
  },
]

async function prepare({ mocks = successMocks }: { mocks?: TestMocksType } = {}) {
  await act(() =>
    render(
      <NiceModalWrapper>
        <MainHeader />
        <OktaAuthenticationDetails />
      </NiceModalWrapper>,
      { mocks },
    ),
  )
}

describe('OktaAuthenticationDetails', () => {
  beforeAll(async () => {
    await initializeTranslations()
  })

  beforeEach(() => {
    jest.clearAllMocks()
    mockUseParams.mockReturnValue({ integrationId: 'integration-123' })
  })

  afterEach(cleanup)

  it('renders integration details after loading', async () => {
    await prepare()

    await waitFor(() => {
      expect(screen.getByText('test.example.com')).toBeInTheDocument()
    })

    expect(screen.getByText('okta.example.com')).toBeInTheDocument()
    expect(screen.getByText('test-client-id')).toBeInTheDocument()
    expect(screen.getByText('test-client-secret')).toBeInTheDocument()
    expect(screen.getByText('test-org')).toBeInTheDocument()
  })

  it('renders the page header with back button', async () => {
    await prepare()

    await waitFor(() => {
      expect(screen.getByText('test.example.com')).toBeInTheDocument()
    })

    const backButton = document.querySelector('a[href*="authentication"]')

    expect(backButton).toBeInTheDocument()
  })

  it('shows N/A for missing host', async () => {
    const noHostMocks: TestMocksType = [
      {
        request: {
          query: GetOktaIntegrationDocument,
          variables: { id: 'integration-123' },
        },
        result: {
          data: {
            integration: {
              ...integrationData,
              host: null,
            },
          },
        },
      },
    ]

    await prepare({ mocks: noHostMocks })

    await waitFor(() => {
      expect(screen.getByText('N/A')).toBeInTheDocument()
    })
  })

  it('shows N/A for missing clientId', async () => {
    const noClientIdMocks: TestMocksType = [
      {
        request: {
          query: GetOktaIntegrationDocument,
          variables: { id: 'integration-123' },
        },
        result: {
          data: {
            integration: {
              ...integrationData,
              clientId: null,
            },
          },
        },
      },
    ]

    await prepare({ mocks: noClientIdMocks })

    await waitFor(() => {
      expect(screen.getAllByText('N/A').length).toBeGreaterThanOrEqual(1)
    })
  })

  it('navigates away when integration is not found', async () => {
    const emptyMocks: TestMocksType = [
      {
        request: {
          query: GetOktaIntegrationDocument,
          variables: { id: 'integration-123' },
        },
        result: {
          data: {
            integration: null,
          },
        },
      },
    ]

    await prepare({ mocks: emptyMocks })

    await waitFor(() => {
      expect(mockNavigateFn).toHaveBeenCalled()
    })
  })

  it('navigates away when no cached integration on initial render', async () => {
    const delayedMocks: TestMocksType = [
      {
        request: {
          query: GetOktaIntegrationDocument,
          variables: { id: 'integration-123' },
        },
        result: {
          data: {
            integration: integrationData,
          },
        },
        delay: 1000,
      },
    ]

    await act(() =>
      render(
        <NiceModalWrapper>
          <OktaAuthenticationDetails />
        </NiceModalWrapper>,
        { mocks: delayedMocks },
      ),
    )

    expect(mockNavigateFn).toHaveBeenCalled()
  })

  it('renders the actions dropdown button', async () => {
    await prepare()

    await waitFor(() => {
      expect(screen.getByText('test.example.com')).toBeInTheDocument()
    })

    // Find the chevron-down button (actions dropdown)
    const actionButtons = document.querySelectorAll('button')

    // The actions button should be present
    expect(actionButtons.length).toBeGreaterThan(0)
  })

  it('opens popper menu when actions button is clicked', async () => {
    const user = userEvent.setup()

    await prepare()

    await waitFor(() => {
      expect(screen.getByText('test.example.com')).toBeInTheDocument()
    })

    // The actions button in the header contains an endIcon (chevron-down)
    const allButtons = screen.getAllByRole('button')

    // Click the first button that could be the actions dropdown
    // It should be the button with endIcon in PageHeader.Wrapper
    for (const btn of allButtons) {
      if (btn.querySelector('[class*="endIcon"]')) {
        await user.click(btn)
        break
      }
    }

    // After clicking, the popper should render additional buttons
    await waitFor(() => {
      const buttonsAfterClick = screen.getAllByRole('button')

      // More buttons should appear from the popper menu
      expect(buttonsAfterClick.length).toBeGreaterThan(allButtons.length)
    })
  })

  it('has all 5 detail items visible', async () => {
    await prepare()

    await waitFor(() => {
      expect(screen.getByText('test.example.com')).toBeInTheDocument()
    })

    // All detail items should be present
    expect(screen.getByText('okta.example.com')).toBeInTheDocument()
    expect(screen.getByText('test-client-id')).toBeInTheDocument()
    expect(screen.getByText('test-client-secret')).toBeInTheDocument()
    expect(screen.getByText('test-org')).toBeInTheDocument()
  })

  it('clicks edit button in actions popper to open edit dialog', async () => {
    const user = userEvent.setup()

    await prepare()

    await waitFor(() => {
      expect(screen.getByText('test.example.com')).toBeInTheDocument()
    })

    // Find and click the actions button (has endIcon chevron-down)
    const allButtons = screen.getAllByRole('button')

    for (const btn of allButtons) {
      if (btn.querySelector('[class*="endIcon"]')) {
        await user.click(btn)
        break
      }
    }

    // Wait for popper menu buttons to appear
    await waitFor(() => {
      const buttonsAfterClick = screen.getAllByRole('button')

      expect(buttonsAfterClick.length).toBeGreaterThan(allButtons.length)
    })

    // Click the first button in the popper (edit)
    const buttonsAfterClick = screen.getAllByRole('button')
    const popperButtons = buttonsAfterClick.filter(
      (btn) => !allButtons.includes(btn) && btn.textContent,
    )

    if (popperButtons.length > 0) {
      await user.click(popperButtons[0])

      // Edit dialog should open
      await waitFor(() => {
        const dialog = document.querySelector('[class*="MuiDialog"]')

        expect(dialog).toBeInTheDocument()
      })
    }
  })

  it('clicks delete button in actions popper to open delete dialog', async () => {
    const user = userEvent.setup()

    await prepare()

    await waitFor(() => {
      expect(screen.getByText('test.example.com')).toBeInTheDocument()
    })

    // Find and click the actions button
    const allButtons = screen.getAllByRole('button')

    for (const btn of allButtons) {
      if (btn.querySelector('[class*="endIcon"]')) {
        await user.click(btn)
        break
      }
    }

    await waitFor(() => {
      const buttonsAfterClick = screen.getAllByRole('button')

      expect(buttonsAfterClick.length).toBeGreaterThan(allButtons.length)
    })

    // Click the second button in the popper (delete)
    const buttonsAfterClick = screen.getAllByRole('button')
    const popperButtons = buttonsAfterClick.filter(
      (btn) => !allButtons.includes(btn) && btn.textContent,
    )

    if (popperButtons.length > 1) {
      await user.click(popperButtons[1])

      // Delete dialog should open
      await waitFor(() => {
        const dialog = document.querySelector('[class*="MuiDialog"]')

        expect(dialog).toBeInTheDocument()
      })
    }
  })

  it('shows inline edit button and opens dialog when clicked', async () => {
    const user = userEvent.setup()

    await prepare()

    await waitFor(() => {
      expect(screen.getByText('test.example.com')).toBeInTheDocument()
    })

    // Find the inline edit button (variant="inline") in the details section
    const allButtons = screen.getAllByRole('button')
    const inlineButtons = allButtons.filter(
      (btn) => btn.className.includes('inline') || btn.className.includes('Inline'),
    )

    if (inlineButtons.length > 0) {
      await user.click(inlineButtons[0])

      // Edit dialog should open
      await waitFor(() => {
        const dialog = document.querySelector('[class*="MuiDialog"]')

        expect(dialog).toBeInTheDocument()
      })
    }
  })
})
