import { useMemo, useState } from 'react'
import { generatePath, useSearchParams } from 'react-router-dom'

import { Avatar } from '~/components/designSystem/Avatar'
import { Chip } from '~/components/designSystem/Chip'
import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { Table, TableColumn } from '~/components/designSystem/Table/Table'
import { ActionColumn, ActionItem } from '~/components/designSystem/Table/types'
import { Typography } from '~/components/designSystem/Typography'
import { addToast } from '~/core/apolloClient'
import { MEMBERS_PAGE_ROLE_FILTER_KEY, RoleItem } from '~/core/constants/roles'
import { INVITATION_ROUTE } from '~/core/router'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import { GetInvitesQuery, InviteItemForMembersSettingsFragment } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { usePermissions } from '~/hooks/usePermissions'
import { AllowedElements, useRoleDisplayInformation } from '~/hooks/useRoleDisplayInformation'
import { useRolesList } from '~/hooks/useRolesList'

import MembersFilters from './common/MembersFilters'
import { useCreateInviteDialog } from './dialogs/CreateInviteDialog'
import { useEditInviteRoleDialog } from './dialogs/EditInviteRoleDialog'
import { useRevokeInviteDialog } from './dialogs/RevokeInviteDialog'
import { useGetMembersInvitationList } from './hooks/useGetMembersInvitationsList'

type Invitation = GetInvitesQuery['invites']['collection'][0]

const EmailColumn = ({ email }: { email: string | null }) => (
  <div className="flex flex-1 items-center gap-3">
    <Avatar variant="user" identifier={(email || '').charAt(0)} size="big" />
    <Typography variant="body" color="grey700">
      {email}
    </Typography>
  </div>
)

const getRolesColumn = (
  allRoles: Array<RoleItem>,
  getDisplayName: (role: AllowedElements) => string,
) =>
  function RolesColumnInside({ roles }: { roles: string[] }) {
    const roleToDisplay = allRoles.find((r) => r.code === roles[0])

    return <Chip label={getDisplayName(roleToDisplay)} />
  }

const MembersInvitationList = () => {
  const { translate } = useInternationalization()
  const { invitations, metadata, invitesLoading, invitesFetchMore, invitesError, invitesRefetch } =
    useGetMembersInvitationList()
  const { roles } = useRolesList()
  const { getDisplayName } = useRoleDisplayInformation()
  const { hasPermissions } = usePermissions()

  const RolesColumn = getRolesColumn(roles, getDisplayName)

  const { openCreateInviteDialog } = useCreateInviteDialog()
  const { openEditInviteRoleDialog } = useEditInviteRoleDialog()
  const { openRevokeInviteDialog } = useRevokeInviteDialog()

  const [searchParams] = useSearchParams()

  const selectedRole = useMemo(() => {
    return searchParams.get(MEMBERS_PAGE_ROLE_FILTER_KEY)
  }, [searchParams])

  const [searchQuery, setSearchQuery] = useState('')

  const filteredInvitations = useMemo(() => {
    if (!selectedRole && !searchQuery) return invitations

    return invitations.filter((invitation) => {
      const matchesRole = !selectedRole || invitation.roles.includes(selectedRole)
      const matchesSearch =
        !searchQuery || invitation.email?.toLowerCase().includes(searchQuery.toLowerCase())

      return matchesRole && matchesSearch
    })
  }, [invitations, selectedRole, searchQuery])

  const handleInfiniteScrolling = () => {
    const { currentPage = 0, totalPages = 0 } = metadata || {}

    currentPage < totalPages &&
      !invitesLoading &&
      invitesFetchMore({
        variables: { page: currentPage + 1 },
      })
  }

  const columns: Array<TableColumn<Invitation> | null> = [
    {
      key: 'email',
      title: translate('text_63208b630aaf8df6bbfb2655'),
      maxSpace: true,
      content: EmailColumn,
    },
    {
      key: 'roles.0',
      title: translate('text_664f035a68227f00e261b7ec'),
      minWidth: 170,
      content: RolesColumn,
    },
  ]

  const actionColumn: ActionColumn<Invitation> = (invite) => {
    if (
      !hasPermissions(['organizationMembersUpdate']) &&
      !hasPermissions(['organizationMembersDelete'])
    ) {
      return undefined
    }

    const editAction = hasPermissions(['organizationMembersUpdate'])
      ? [
          {
            startIcon: 'pen',
            title: translate('text_664f035a68227f00e261b7f6'),
            onAction: () => {
              openEditInviteRoleDialog(invite)
            },
          } as ActionItem<InviteItemForMembersSettingsFragment>,
        ]
      : []

    const duplicateAction: ActionItem<InviteItemForMembersSettingsFragment> = {
      startIcon: 'duplicate',
      title: translate('text_63208b630aaf8df6bbfb265f'),
      onAction: () => {
        copyToClipboard(
          `${globalThis.location.origin}${generatePath(INVITATION_ROUTE, {
            token: invite.token,
          })}`,
        )

        addToast({
          severity: 'info',
          translateKey: 'text_63208b630aaf8df6bbfb2679',
        })
      },
      dataTest: 'copy-invite-link',
    }

    const deleteAction = hasPermissions(['organizationMembersDelete'])
      ? [
          {
            startIcon: 'trash',
            title: translate('text_63208c701ce25db78140745e'),
            onAction: () => {
              openRevokeInviteDialog({
                id: invite.id,
                email: invite.email,
                organizationName: invite.organization.name,
              })
            },
          } as ActionItem<InviteItemForMembersSettingsFragment>,
        ]
      : []

    return [...editAction, duplicateAction, ...deleteAction]
  }

  const getTablePlaceholder = () => {
    const errorState = {
      errorState: {
        title: translate('text_6321a076b94bd1b32494e9ee'),
        subtitle: translate('text_6321a076b94bd1b32494e9e8'),
        buttonTitle: translate('text_6321a076b94bd1b32494e9f2'),
        buttonAction: () => {
          invitesRefetch()
        },
      },
    }

    const sharedEmptyState = {
      buttonTitle: translate('text_63208b630aaf8df6bbfb265b'),
      buttonAction: openCreateInviteDialog,
    }

    if (searchQuery || selectedRole) {
      return {
        ...errorState,
        emptyState: {
          title: translate('text_1767714241102zgu36uubm70'),
          subtitle: translate('text_1767714241102xpwokcuhvki'),
          ...sharedEmptyState,
        },
      }
    }

    return {
      ...errorState,
      emptyState: {
        title: translate('text_17671750294886x8eq8lizmt'),
        subtitle: translate('text_1767175029488r5limdbdwm5'),
        ...sharedEmptyState,
      },
    }
  }

  return (
    <div>
      <MembersFilters
        searchQuery={searchQuery}
        setSearchQuery={setSearchQuery}
        type="invitations"
      />
      <InfiniteScroll onBottom={handleInfiniteScrolling}>
        <Table
          name="members-setting-invitations-list"
          containerSize={{ default: 0 }}
          rowSize={72}
          isLoading={invitesLoading}
          data={filteredInvitations}
          hasError={!!invitesError}
          placeholder={getTablePlaceholder()}
          columns={columns}
          actionColumnTooltip={() => translate('text_626162c62f790600f850b7b6')}
          actionColumn={actionColumn}
        />
      </InfiniteScroll>
    </div>
  )
}

export default MembersInvitationList
