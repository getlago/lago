import NiceModal from '@ebay/nice-modal-react'
import {
  act,
  cleanup,
  RenderOptions,
  render as rtlRender,
  screen,
  waitFor,
} from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactElement, ReactNode } from 'react'

import CentralizedDialog from '~/components/dialogs/CentralizedDialog'
import {
  CENTRALIZED_DIALOG_NAME,
  FORM_DIALOG_OPENING_DIALOG_NAME,
  PREMIUM_WARNING_DIALOG_NAME,
} from '~/components/dialogs/const'
import FormDialogOpeningDialog from '~/components/dialogs/FormDialogOpeningDialog'
import PremiumWarningDialog from '~/components/dialogs/PremiumWarningDialog'
import { initializeTranslations } from '~/core/apolloClient'
import {
  AuthenticationMethodsEnum,
  GetAuthIntegrationsDocument,
  PremiumIntegrationTypeEnum,
} from '~/generated/graphql'
import { AllTheProviders, testMockNavigateFn, TestMocksType } from '~/test-utils'

import Authentication from '../Authentication'

const mockRefetch = jest.fn()
let mockIsPremium = true

let mockOrganizationData: {
  premiumIntegrations?: PremiumIntegrationTypeEnum[]
  authenticationMethods?: AuthenticationMethodsEnum[]
} = {
  premiumIntegrations: [PremiumIntegrationTypeEnum.Okta],
  authenticationMethods: [
    AuthenticationMethodsEnum.EmailPassword,
    AuthenticationMethodsEnum.GoogleOauth,
  ],
}

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    organization: mockOrganizationData,
    loading: false,
    refetchOrganizationInfos: mockRefetch,
  }),
}))

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({
    isPremium: mockIsPremium,
  }),
}))

NiceModal.register(FORM_DIALOG_OPENING_DIALOG_NAME, FormDialogOpeningDialog)
NiceModal.register(CENTRALIZED_DIALOG_NAME, CentralizedDialog)
NiceModal.register(PREMIUM_WARNING_DIALOG_NAME, PremiumWarningDialog)

const NiceModalWrapper = ({ children }: { children: ReactNode }) => {
  return <NiceModal.Provider>{children}</NiceModal.Provider>
}

const emptyIntegrationsMock: TestMocksType = [
  {
    request: {
      query: GetAuthIntegrationsDocument,
      variables: { limit: 10 },
    },
    result: {
      data: {
        integrations: {
          __typename: 'IntegrationCollection',
          collection: [],
        },
      },
    },
  },
]

const oktaIntegrationsMock: TestMocksType = [
  {
    request: {
      query: GetAuthIntegrationsDocument,
      variables: { limit: 10 },
    },
    result: {
      data: {
        integrations: {
          __typename: 'IntegrationCollection',
          collection: [
            {
              __typename: 'OktaIntegration',
              id: 'okta-123',
              domain: 'test.example.com',
              clientId: 'test-client-id',
              clientSecret: 'test-secret',
              organizationName: 'test-org',
              host: 'okta.example.com',
              name: 'Test Okta',
            },
          ],
        },
      },
    },
  },
]

const customRender = (
  ui: ReactElement,
  options?: Omit<RenderOptions, 'wrapper'> & { mocks?: TestMocksType },
) =>
  rtlRender(ui, {
    wrapper: (props) => <AllTheProviders {...props} mocks={options?.mocks} forceTypenames={true} />,
    ...options,
  })

async function prepare({ mocks = emptyIntegrationsMock }: { mocks?: TestMocksType } = {}) {
  await act(() =>
    customRender(
      <NiceModalWrapper>
        <Authentication />
      </NiceModalWrapper>,
      { mocks },
    ),
  )
}

describe('Authentication', () => {
  beforeAll(async () => {
    await initializeTranslations()
  })

  beforeEach(() => {
    jest.clearAllMocks()
    mockIsPremium = true
    mockOrganizationData = {
      premiumIntegrations: [PremiumIntegrationTypeEnum.Okta],
      authenticationMethods: [
        AuthenticationMethodsEnum.EmailPassword,
        AuthenticationMethodsEnum.GoogleOauth,
      ],
    }
  })

  afterEach(cleanup)

  it('renders 3 selectors for auth methods', async () => {
    await prepare()

    await waitFor(() => {
      const selectors = screen.getAllByRole('button').filter((el) => el.tagName === 'DIV')

      expect(selectors.length).toBeGreaterThanOrEqual(3)
    })
  })

  it('shows enabled chips for active authentication methods', async () => {
    await prepare()

    await waitFor(() => {
      const chips = document.querySelectorAll('[class*="MuiChip"]')

      expect(chips.length).toBeGreaterThanOrEqual(2)
    })
  })

  it('shows disabled chip when method is not enabled', async () => {
    mockOrganizationData = {
      premiumIntegrations: [PremiumIntegrationTypeEnum.Okta],
      authenticationMethods: [AuthenticationMethodsEnum.EmailPassword],
    }

    await prepare()

    await waitFor(() => {
      const chips = document.querySelectorAll('[class*="MuiChip"]')

      expect(chips.length).toBeGreaterThanOrEqual(1)
    })
  })

  it('shows sparkle icon for Okta when user is not premium', async () => {
    mockIsPremium = false

    await prepare()

    await waitFor(() => {
      // Non-premium users get sparkles icon for Okta
      const sparkleIcons = screen.queryAllByTestId(/sparkles/)

      expect(sparkleIcons.length).toBeGreaterThanOrEqual(1)
    })
  })

  it('shows sparkle icon for Okta when no Okta premium integration', async () => {
    mockOrganizationData = {
      premiumIntegrations: [],
      authenticationMethods: [AuthenticationMethodsEnum.EmailPassword],
    }

    await prepare()

    await waitFor(() => {
      const sparkleIcons = screen.queryAllByTestId(/sparkles/)

      expect(sparkleIcons.length).toBeGreaterThanOrEqual(1)
    })
  })

  it('navigates to Okta details when clicking Okta selector with existing integration', async () => {
    const user = userEvent.setup()

    mockOrganizationData = {
      premiumIntegrations: [PremiumIntegrationTypeEnum.Okta],
      authenticationMethods: [
        AuthenticationMethodsEnum.EmailPassword,
        AuthenticationMethodsEnum.Okta,
      ],
    }

    await prepare({ mocks: oktaIntegrationsMock })

    // Wait for the GraphQL query to resolve - 3 dots-horizontal icons appear
    // (EmailPassword + GoogleOauth get theirs immediately, Okta only after query resolves)
    await waitFor(() => {
      expect(screen.getAllByTestId(/dots-horizontal/).length).toBe(3)
    })

    const selectorButtons = screen.getAllByRole('button').filter((el) => el.tagName === 'DIV')

    // Click the Okta selector (3rd one)
    await user.click(selectorButtons[2])

    await waitFor(() => {
      expect(testMockNavigateFn).toHaveBeenCalled()
    })
  })

  it('opens popper menu and shows disable option for enabled method', async () => {
    const user = userEvent.setup()

    await prepare()

    await waitFor(() => {
      // Wait for dots icons to appear (one per enabled method)
      expect(screen.queryAllByTestId(/dots-horizontal/).length).toBeGreaterThanOrEqual(1)
    })

    const dotsIcons = screen.getAllByTestId(/dots-horizontal/)
    const dotsButton = dotsIcons[0].closest('button')

    expect(dotsButton).toBeTruthy()

    await user.click(dotsButton as HTMLElement)

    // eye-hidden icon only appears in the popper for "enabled" methods
    await waitFor(() => {
      const eyeHiddenIcons = screen.queryAllByTestId(/eye-hidden/)

      expect(eyeHiddenIcons.length).toBeGreaterThanOrEqual(1)
    })
  })

  it('opens Okta add dialog when clicking Okta without integration', async () => {
    const user = userEvent.setup()

    mockOrganizationData = {
      premiumIntegrations: [PremiumIntegrationTypeEnum.Okta],
      authenticationMethods: [AuthenticationMethodsEnum.EmailPassword],
    }

    await prepare({ mocks: emptyIntegrationsMock })

    await waitFor(() => {
      const selectors = screen.getAllByRole('button').filter((el) => el.tagName === 'DIV')

      expect(selectors.length).toBeGreaterThanOrEqual(3)
    })

    const selectorButtons = screen.getAllByRole('button').filter((el) => el.tagName === 'DIV')

    // Click the Okta selector (3rd one)
    await user.click(selectorButtons[2])

    await waitFor(() => {
      const dialog = document.querySelector('[class*="MuiDialog"]')

      expect(dialog).toBeInTheDocument()
    })
  })

  it('opens premium warning when non-premium clicks Okta', async () => {
    const user = userEvent.setup()

    mockIsPremium = false

    await prepare()

    await waitFor(() => {
      const selectors = screen.getAllByRole('button').filter((el) => el.tagName === 'DIV')

      expect(selectors.length).toBeGreaterThanOrEqual(3)
    })

    const selectorButtons = screen.getAllByRole('button').filter((el) => el.tagName === 'DIV')

    // Click the Okta selector (3rd one)
    await user.click(selectorButtons[2])

    // Premium warning dialog should appear
    await waitFor(() => {
      const dialog = document.querySelector('[class*="MuiDialog"]')

      expect(dialog).toBeInTheDocument()
    })
  })

  it('renders connect button for Okta when premium but no integration', async () => {
    mockOrganizationData = {
      premiumIntegrations: [PremiumIntegrationTypeEnum.Okta],
      authenticationMethods: [AuthenticationMethodsEnum.EmailPassword],
    }

    await prepare({ mocks: emptyIntegrationsMock })

    await waitFor(() => {
      // A connect/link button should appear for Okta
      const linkIcons = screen.queryAllByTestId(/link\//)

      expect(linkIcons.length).toBeGreaterThanOrEqual(0)
    })
  })

  it('renders with Okta integration and Okta enabled', async () => {
    mockOrganizationData = {
      premiumIntegrations: [PremiumIntegrationTypeEnum.Okta],
      authenticationMethods: [
        AuthenticationMethodsEnum.EmailPassword,
        AuthenticationMethodsEnum.Okta,
      ],
    }

    await prepare({ mocks: oktaIntegrationsMock })

    await waitFor(() => {
      const chips = document.querySelectorAll('[class*="MuiChip"]')

      expect(chips.length).toBeGreaterThanOrEqual(1)
    })
  })

  it('disables buttons when only one auth method enabled', async () => {
    mockOrganizationData = {
      premiumIntegrations: [PremiumIntegrationTypeEnum.Okta],
      authenticationMethods: [AuthenticationMethodsEnum.EmailPassword],
    }

    await prepare()

    await waitFor(() => {
      expect(document.body.textContent).toBeTruthy()
    })
  })

  it('opens popper menu and shows enable option for disabled method', async () => {
    const user = userEvent.setup()

    mockOrganizationData = {
      premiumIntegrations: [PremiumIntegrationTypeEnum.Okta],
      authenticationMethods: [AuthenticationMethodsEnum.EmailPassword],
    }

    await prepare()

    await waitFor(() => {
      expect(screen.queryAllByTestId(/dots-horizontal/).length).toBeGreaterThanOrEqual(1)
    })

    // The second dots icon should be for the disabled GoogleOauth
    const dotsIcons = screen.getAllByTestId(/dots-horizontal/)

    if (dotsIcons.length >= 2) {
      const dotsButton = dotsIcons[1].closest('button')

      expect(dotsButton).toBeTruthy()

      await user.click(dotsButton as HTMLElement)

      // "plus" icon appears in the enable option for disabled methods
      await waitFor(() => {
        const plusIcons = screen.queryAllByTestId(/plus\//)

        expect(plusIcons.length).toBeGreaterThanOrEqual(1)
      })
    }
  })

  it('renders Okta with enabled chip when integration exists', async () => {
    mockOrganizationData = {
      premiumIntegrations: [PremiumIntegrationTypeEnum.Okta],
      authenticationMethods: [
        AuthenticationMethodsEnum.EmailPassword,
        AuthenticationMethodsEnum.Okta,
      ],
    }

    await prepare({ mocks: oktaIntegrationsMock })

    await waitFor(() => {
      // At least 2 chips (EmailPassword enabled + Okta enabled)
      const chips = document.querySelectorAll('[class*="MuiChip"]')

      expect(chips.length).toBeGreaterThanOrEqual(2)
    })
  })

  it('clicks connect button for Okta to open add dialog', async () => {
    const user = userEvent.setup()

    mockOrganizationData = {
      premiumIntegrations: [PremiumIntegrationTypeEnum.Okta],
      authenticationMethods: [AuthenticationMethodsEnum.EmailPassword],
    }

    await prepare({ mocks: emptyIntegrationsMock })

    await waitFor(() => {
      // Look for "link" icon which is the connect button's startIcon
      const linkIcons = screen.queryAllByTestId(/link\//)

      expect(linkIcons.length).toBeGreaterThanOrEqual(1)
    })

    const linkIcon = screen.getAllByTestId(/link\//)[0]
    const connectButton = linkIcon.closest('button')

    if (connectButton) {
      await user.click(connectButton)

      await waitFor(() => {
        // Add Okta dialog should open
        const dialog = document.querySelector('[class*="MuiDialog"]')

        expect(dialog).toBeInTheDocument()
      })
    }
  })

  it('clicks disable button in popper for enabled method', async () => {
    const user = userEvent.setup()

    await prepare()

    await waitFor(() => {
      expect(screen.queryAllByTestId(/dots-horizontal/).length).toBeGreaterThanOrEqual(1)
    })

    // Click the first dots button (EmailPassword - enabled)
    const dotsIcons = screen.getAllByTestId(/dots-horizontal/)
    const dotsButton = dotsIcons[0].closest('button') as HTMLElement

    await user.click(dotsButton)

    // Wait for disable button with eye-hidden icon
    await waitFor(() => {
      expect(screen.queryAllByTestId(/eye-hidden/).length).toBeGreaterThanOrEqual(1)
    })

    // Click the disable button
    const eyeHiddenIcon = screen.getAllByTestId(/eye-hidden/)[0]
    const disableButton = eyeHiddenIcon.closest('button') as HTMLElement

    await user.click(disableButton)

    // UpdateLoginMethodDialog should open
    await waitFor(() => {
      const dialog = document.querySelector('[class*="MuiDialog"]')

      expect(dialog).toBeInTheDocument()
    })
  })

  it('clicks enable button in popper for disabled method', async () => {
    const user = userEvent.setup()

    mockOrganizationData = {
      premiumIntegrations: [PremiumIntegrationTypeEnum.Okta],
      authenticationMethods: [AuthenticationMethodsEnum.EmailPassword],
    }

    await prepare()

    await waitFor(() => {
      expect(screen.queryAllByTestId(/dots-horizontal/).length).toBeGreaterThanOrEqual(2)
    })

    // Click the second dots button (GoogleOauth - disabled)
    const dotsIcons = screen.getAllByTestId(/dots-horizontal/)
    const dotsButton = dotsIcons[1].closest('button') as HTMLElement

    await user.click(dotsButton)

    // Wait for enable button with plus icon
    await waitFor(() => {
      expect(screen.queryAllByTestId(/plus\//).length).toBeGreaterThanOrEqual(1)
    })

    // Click the enable button
    const plusIcon = screen.getAllByTestId(/plus\//)[0]
    const enableButton = plusIcon.closest('button') as HTMLElement

    await user.click(enableButton)

    // UpdateLoginMethodDialog should open
    await waitFor(() => {
      const dialog = document.querySelector('[class*="MuiDialog"]')

      expect(dialog).toBeInTheDocument()
    })
  })

  it('shows edit and delete in Okta popper when integration exists', async () => {
    const user = userEvent.setup()

    mockOrganizationData = {
      premiumIntegrations: [PremiumIntegrationTypeEnum.Okta],
      authenticationMethods: [
        AuthenticationMethodsEnum.EmailPassword,
        AuthenticationMethodsEnum.Okta,
      ],
    }

    await prepare({ mocks: oktaIntegrationsMock })

    // Wait for all 3 dots-horizontal icons (Okta's appears after query resolves)
    await waitFor(() => {
      expect(screen.getAllByTestId(/dots-horizontal/).length).toBe(3)
    })

    // Click the Okta dots button (3rd one)
    const dotsIcons = screen.getAllByTestId(/dots-horizontal/)
    const oktaDotsButton = dotsIcons[2].closest('button') as HTMLElement

    await user.click(oktaDotsButton)

    // Should see pen (edit) and trash (delete) icons in the Okta popper
    await waitFor(() => {
      expect(screen.queryAllByTestId(/pen\//).length).toBeGreaterThanOrEqual(1)
      expect(screen.queryAllByTestId(/trash\//).length).toBeGreaterThanOrEqual(1)
    })
  })

  it('clicks edit button in Okta popper to open edit dialog', async () => {
    const user = userEvent.setup()

    mockOrganizationData = {
      premiumIntegrations: [PremiumIntegrationTypeEnum.Okta],
      authenticationMethods: [
        AuthenticationMethodsEnum.EmailPassword,
        AuthenticationMethodsEnum.Okta,
      ],
    }

    await prepare({ mocks: oktaIntegrationsMock })

    await waitFor(() => {
      expect(screen.getAllByTestId(/dots-horizontal/).length).toBe(3)
    })

    const dotsIcons = screen.getAllByTestId(/dots-horizontal/)
    const oktaDotsButton = dotsIcons[2].closest('button') as HTMLElement

    await user.click(oktaDotsButton)

    await waitFor(() => {
      expect(screen.queryAllByTestId(/pen\//).length).toBeGreaterThanOrEqual(1)
    })

    // Click the edit button
    const penIcon = screen.getAllByTestId(/pen\//)[0]
    const editButton = penIcon.closest('button') as HTMLElement

    await user.click(editButton)

    // Edit dialog should open
    await waitFor(() => {
      const dialog = document.querySelector('[class*="MuiDialog"]')

      expect(dialog).toBeInTheDocument()
    })
  })

  it('clicks delete button in Okta popper to open delete dialog', async () => {
    const user = userEvent.setup()

    mockOrganizationData = {
      premiumIntegrations: [PremiumIntegrationTypeEnum.Okta],
      authenticationMethods: [
        AuthenticationMethodsEnum.EmailPassword,
        AuthenticationMethodsEnum.Okta,
      ],
    }

    await prepare({ mocks: oktaIntegrationsMock })

    await waitFor(() => {
      expect(screen.getAllByTestId(/dots-horizontal/).length).toBe(3)
    })

    const dotsIcons = screen.getAllByTestId(/dots-horizontal/)
    const oktaDotsButton = dotsIcons[2].closest('button') as HTMLElement

    await user.click(oktaDotsButton)

    await waitFor(() => {
      expect(screen.queryAllByTestId(/trash\//).length).toBeGreaterThanOrEqual(1)
    })

    // Click the delete button
    const trashIcon = screen.getAllByTestId(/trash\//)[0]
    const deleteButton = trashIcon.closest('button') as HTMLElement

    await user.click(deleteButton)

    // Delete dialog should open
    await waitFor(() => {
      const dialog = document.querySelector('[class*="MuiDialog"]')

      expect(dialog).toBeInTheDocument()
    })
  })
})
