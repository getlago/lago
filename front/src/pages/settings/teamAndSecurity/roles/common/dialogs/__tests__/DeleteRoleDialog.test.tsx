import NiceModal from '@ebay/nice-modal-react'
import { cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactNode, useEffect } from 'react'

import CentralizedDialog from '~/components/dialogs/CentralizedDialog'
import {
  CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID,
  CENTRALIZED_DIALOG_NAME,
} from '~/components/dialogs/const'
import { RoleItem } from '~/core/constants/roles'
import { PermissionEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { useDeleteRoleDialog } from '../DeleteRoleDialog'

// Register the dialog
NiceModal.register(CENTRALIZED_DIALOG_NAME, CentralizedDialog)

const mockDeleteRole = jest.fn()

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string, params?: Record<string, string>) => {
      if (params?.roleName) {
        return `${key} - ${params.roleName}`
      }
      return key
    },
  }),
}))

jest.mock('../../../hooks/useRoleActions', () => ({
  useRoleActions: () => ({
    deleteRole: mockDeleteRole,
    isDeletingRole: false,
    deleteRoleError: undefined,
  }),
}))

const mockRole: RoleItem = {
  __typename: 'Role',
  id: 'role-123',
  name: 'Custom Role',
  description: 'A custom test role',
  code: 'custom_role',
  admin: false,
  memberships: [],
  permissions: [PermissionEnum.PlansView],
}

const NiceModalWrapper = ({ children }: { children: ReactNode }) => {
  return <NiceModal.Provider>{children}</NiceModal.Provider>
}

const TestComponent = ({ role, autoOpen = true }: { role: RoleItem; autoOpen?: boolean }) => {
  const { openDeleteRoleDialog } = useDeleteRoleDialog()

  useEffect(() => {
    if (autoOpen) {
      openDeleteRoleDialog(role)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [autoOpen])

  return null
}

describe('useDeleteRoleDialog', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  it('opens dialog with role name in description', async () => {
    render(
      <NiceModalWrapper>
        <TestComponent role={mockRole} />
      </NiceModalWrapper>,
    )

    await waitFor(() => {
      expect(screen.getByText(/Custom Role/)).toBeInTheDocument()
    })
  })

  it('renders confirm button', async () => {
    render(
      <NiceModalWrapper>
        <TestComponent role={mockRole} />
      </NiceModalWrapper>,
    )

    await waitFor(() => {
      expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeInTheDocument()
    })
  })

  it('calls deleteRole when confirm button is clicked', async () => {
    const user = userEvent.setup()

    mockDeleteRole.mockResolvedValue(undefined)

    render(
      <NiceModalWrapper>
        <TestComponent role={mockRole} />
      </NiceModalWrapper>,
    )

    await waitFor(() => {
      expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeInTheDocument()
    })

    await user.click(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID))

    await waitFor(() => {
      expect(mockDeleteRole).toHaveBeenCalledWith({
        id: 'role-123',
      })
    })
  })
})
