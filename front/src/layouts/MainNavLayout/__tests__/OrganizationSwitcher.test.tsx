import { ApolloClient, InMemoryCache } from '@apollo/client'
import { screen } from '@testing-library/react'

import { render } from '~/test-utils'

import {
  ORGANIZATION_SWITCHER_BUTTON_TEST_ID,
  ORGANIZATION_SWITCHER_LOGOUT_TEST_ID,
  ORGANIZATION_SWITCHER_NAME_TEST_ID,
  ORGANIZATION_SWITCHER_ORG_ITEM_TEST_ID,
  ORGANIZATION_SWITCHER_TEST_ID,
  ORGANIZATION_SWITCHER_VERSION_LINK_TEST_ID,
  OrganizationSwitcher,
} from '../OrganizationSwitcher'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
    locale: 'en',
  }),
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  switchCurrentOrganization: jest.fn(),
  logOut: jest.fn(),
}))

describe('OrganizationSwitcher', () => {
  const mockClient = new ApolloClient({
    cache: new InMemoryCache(),
  })

  const mockCurrentUser = {
    id: 'user-1',
    email: 'test@example.com',
    memberships: [
      {
        id: 'membership-1',
        organization: {
          id: 'org-1',
          name: 'Test Organization',
          slug: 'test-org',
          logoUrl: null,
          accessibleByCurrentSession: true,
        },
      },
      {
        id: 'membership-2',
        organization: {
          id: 'org-2',
          name: 'Another Org',
          slug: 'another-org',
          logoUrl: null,
          accessibleByCurrentSession: true,
        },
      },
    ],
  }

  const mockOrganization = {
    id: 'org-1',
    name: 'Test Organization',
    slug: 'test-org',
    logoUrl: null,
    authenticatedMethod: 'EMAIL',
  }

  // Visual identity in OrganizationSwitcher is now derived from the URL slug
  // (`useParams().organizationSlug`) + `currentUser.memberships`. Tests must
  // mock `organizationSlug` so the lookup resolves to a membership.
  const renderOptions = { useParams: { organizationSlug: 'test-org' } }

  const defaultProps = {
    client: mockClient,
    currentUser: mockCurrentUser as never,
    organization: mockOrganization as never,
    currentVersion: {
      githubUrl: 'https://github.com/getlago/lago',
      number: 'v1.0.0',
    },
    isLoading: false,
    isVersionLoading: false,
  }

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('Test ID constants', () => {
    it('exports expected test ID constants', () => {
      expect(ORGANIZATION_SWITCHER_TEST_ID).toBe('organization-switcher')
      expect(ORGANIZATION_SWITCHER_BUTTON_TEST_ID).toBe('side-nav-user-infos')
      expect(ORGANIZATION_SWITCHER_NAME_TEST_ID).toBe('side-nav-name')
      expect(ORGANIZATION_SWITCHER_LOGOUT_TEST_ID).toBe('side-nav-logout')
      expect(ORGANIZATION_SWITCHER_ORG_ITEM_TEST_ID).toBe('organization-switcher-org-item')
      expect(ORGANIZATION_SWITCHER_VERSION_LINK_TEST_ID).toBe('organization-switcher-version-link')
    })

    it('test ID constants follow kebab-case naming convention', () => {
      const testIds = [
        ORGANIZATION_SWITCHER_TEST_ID,
        ORGANIZATION_SWITCHER_BUTTON_TEST_ID,
        ORGANIZATION_SWITCHER_NAME_TEST_ID,
        ORGANIZATION_SWITCHER_LOGOUT_TEST_ID,
        ORGANIZATION_SWITCHER_ORG_ITEM_TEST_ID,
        ORGANIZATION_SWITCHER_VERSION_LINK_TEST_ID,
      ]

      testIds.forEach((testId) => {
        expect(testId).toMatch(/^[a-z-]+$/)
      })
    })
  })

  describe('Component rendering', () => {
    it('renders the organization switcher container', () => {
      render(<OrganizationSwitcher {...defaultProps} />, renderOptions)

      expect(screen.getByTestId(ORGANIZATION_SWITCHER_TEST_ID)).toBeInTheDocument()
    })

    it('renders the organization switcher button', () => {
      render(<OrganizationSwitcher {...defaultProps} />, renderOptions)

      expect(screen.getByTestId(ORGANIZATION_SWITCHER_BUTTON_TEST_ID)).toBeInTheDocument()
    })

    it('renders the organization name', () => {
      render(<OrganizationSwitcher {...defaultProps} />, renderOptions)

      expect(screen.getByTestId(ORGANIZATION_SWITCHER_NAME_TEST_ID)).toBeInTheDocument()
      expect(screen.getByTestId(ORGANIZATION_SWITCHER_NAME_TEST_ID)).toHaveTextContent(
        'Test Organization',
      )
    })

    it('disables button when loading', () => {
      render(<OrganizationSwitcher {...defaultProps} isLoading={true} />, renderOptions)

      expect(screen.getByTestId(ORGANIZATION_SWITCHER_BUTTON_TEST_ID)).toBeDisabled()
    })
  })

  describe('Component exports', () => {
    it('exports successfully', () => {
      expect(OrganizationSwitcher).toBeDefined()
      expect(typeof OrganizationSwitcher).toBe('function')
    })
  })
})
