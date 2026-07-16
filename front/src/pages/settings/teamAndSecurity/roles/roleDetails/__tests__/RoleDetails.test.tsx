import { act, render as rtlRender, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { MainHeader } from '~/components/MainHeader/MainHeader'
import { MainHeaderProvider } from '~/components/MainHeader/MainHeaderContext'
import {
  ACTIONS_BLOCK_TEST_ID,
  ENTITY_SECTION_METADATA_TEST_ID,
  ENTITY_SECTION_VIEW_NAME_TEST_ID,
} from '~/components/MainHeader/mainHeaderTestIds'
import { AllTheProviders } from '~/test-utils'

import RoleDetails, {
  ROLE_DETAILS_ACTIONS_DROPDOWN_TEST_ID,
  ROLE_DETAILS_DELETE_ACTION_TEST_ID,
  ROLE_DETAILS_DUPLICATE_ACTION_TEST_ID,
  ROLE_DETAILS_EDIT_ACTION_TEST_ID,
} from '../RoleDetails'

const MEMBERS_COUNT_TEST_VALUE = 3

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const mockHasOrganizationPremiumAddon = jest.fn()

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    hasOrganizationPremiumAddon: mockHasOrganizationPremiumAddon,
  }),
}))

const RoleDetailsWithHeader = () => (
  <>
    <MainHeader />
    <RoleDetails />
  </>
)

const render = (ui: React.ReactElement, useParams: Record<string, string> = { roleId: '1' }) =>
  rtlRender(ui, {
    wrapper: ({ children }) => (
      <AllTheProviders useParams={useParams}>
        <MainHeaderProvider>{children}</MainHeaderProvider>
      </AllTheProviders>
    ),
  })

const mockMemberships = Array.from({ length: MEMBERS_COUNT_TEST_VALUE }, (_, i) => ({
  id: `member-${i}`,
}))

jest.mock('../../hooks/useRoleDetails', () => ({
  useRoleDetails: () => ({
    role: {
      id: '1',
      name: 'custom-role',
      code: 'custom-role-code',
      description: 'A custom role description',
      admin: false,
      memberships: mockMemberships,
      permissions: ['PlansView'],
    },
    isLoadingRole: false,
    isSystem: false,
    canBeDuplicated: true,
    canBeEdited: true,
    canBeDeleted: true,
  }),
}))

jest.mock('~/hooks/useRoleDisplayInformation', () => ({
  useRoleDisplayInformation: () => ({
    getDisplayName: (role: { name: string } | undefined) => role?.name || '',
    getDisplayDescription: (role: { description: string } | undefined) => role?.description || '',
  }),
}))

jest.mock('../../hooks/useRoleActions', () => ({
  useRoleActions: () => ({
    navigateToDuplicate: jest.fn(),
    navigateToEdit: jest.fn(),
  }),
}))

jest.mock(
  '~/pages/settings/teamAndSecurity/roles/common/rolePermissionsForm/RolePermissionsForm',
  () => ({
    __esModule: true,
    default: function MockRolePermissionsForm() {
      return <div data-testid="role-permissions-form">Permissions Form</div>
    },
  }),
)

describe('RoleDetails', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockHasOrganizationPremiumAddon.mockReturnValue(true)
  })

  describe('GIVEN the role details page is rendered', () => {
    describe('WHEN the role data is loaded', () => {
      it('THEN should display the role name in the header', async () => {
        await act(() => render(<RoleDetailsWithHeader />))

        const viewName = screen.getAllByTestId(ENTITY_SECTION_VIEW_NAME_TEST_ID)

        expect(viewName.length).toBeGreaterThan(0)
        expect(viewName[0]).toHaveTextContent('custom-role')
      })

      it('THEN should display the role code as metadata', async () => {
        await act(() => render(<RoleDetailsWithHeader />))

        const metadata = screen.getAllByTestId(ENTITY_SECTION_METADATA_TEST_ID)

        expect(metadata.length).toBeGreaterThan(0)
        expect(metadata[0]).toHaveTextContent('custom-role-code')
      })

      it('THEN should display the role description', async () => {
        await act(() => render(<RoleDetailsWithHeader />))

        expect(screen.getByText('A custom role description')).toBeInTheDocument()
      })

      it('THEN should display the actions block', async () => {
        await act(() => render(<RoleDetailsWithHeader />))

        const actionsBlock = screen.getAllByTestId(ACTIONS_BLOCK_TEST_ID)

        expect(actionsBlock.length).toBeGreaterThan(0)
      })
    })
  })

  describe('GIVEN the user has premium addon', () => {
    beforeEach(() => {
      mockHasOrganizationPremiumAddon.mockReturnValue(true)
    })

    describe('WHEN clicking the actions dropdown', () => {
      it('THEN should show duplicate, edit, and delete actions', async () => {
        await act(() => render(<RoleDetailsWithHeader />))

        const dropdownButton = screen.getAllByTestId(ROLE_DETAILS_ACTIONS_DROPDOWN_TEST_ID)[0]

        await userEvent.click(dropdownButton)

        expect(screen.getByTestId(ROLE_DETAILS_DUPLICATE_ACTION_TEST_ID)).toBeInTheDocument()
        expect(screen.getByTestId(ROLE_DETAILS_EDIT_ACTION_TEST_ID)).toBeInTheDocument()
        expect(screen.getByTestId(ROLE_DETAILS_DELETE_ACTION_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the roleId is missing from params', () => {
    it('THEN should display "Role ID is missing"', async () => {
      await act(() => render(<RoleDetailsWithHeader />, {}))

      expect(screen.getByText('Role ID is missing')).toBeInTheDocument()
    })
  })

  describe('GIVEN the role has members', () => {
    it('THEN should render members count with link', async () => {
      await act(() => render(<RoleDetailsWithHeader />))

      expect(screen.getByText(String(MEMBERS_COUNT_TEST_VALUE))).toBeInTheDocument()
    })
  })

  describe('GIVEN the user does not have premium addon', () => {
    beforeEach(() => {
      mockHasOrganizationPremiumAddon.mockReturnValue(false)
    })

    describe('WHEN clicking the actions dropdown', () => {
      it('THEN should show only the duplicate action', async () => {
        await act(() => render(<RoleDetailsWithHeader />))

        const dropdownButton = screen.getAllByTestId(ROLE_DETAILS_ACTIONS_DROPDOWN_TEST_ID)[0]

        await userEvent.click(dropdownButton)

        expect(screen.getByTestId(ROLE_DETAILS_DUPLICATE_ACTION_TEST_ID)).toBeInTheDocument()
        expect(screen.queryByTestId(ROLE_DETAILS_EDIT_ACTION_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(ROLE_DETAILS_DELETE_ACTION_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })
})
