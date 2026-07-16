import { useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'

import { Avatar } from '~/components/designSystem/Avatar'
import { Chip } from '~/components/designSystem/Chip'
import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { Table, TableColumn } from '~/components/designSystem/Table/Table'
import { ActionColumn, ActionItem } from '~/components/designSystem/Table/types'
import { Typography } from '~/components/designSystem/Typography'
import { MEMBERS_PAGE_ROLE_FILTER_KEY } from '~/core/constants/roles'
import { GetMembersQuery, MembershipItemForMembershipSettingsFragment } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { usePermissions } from '~/hooks/usePermissions'
import { AllowedElements, useRoleDisplayInformation } from '~/hooks/useRoleDisplayInformation'

import MembersFilters from './common/MembersFilters'
import { useCreateInviteDialog } from './dialogs/CreateInviteDialog'
import { useEditMemberRoleDialog } from './dialogs/EditMemberRoleDialog'
import { useRevokeMembershipDialog } from './dialogs/RevokeMembershipDialog'
import { useGetMembersList } from './hooks/useGetMembersList'

type Membership = GetMembersQuery['memberships']['collection'][0]

const EmailColumn = ({ user }: Membership) => (
  <div className="flex flex-1 items-center gap-3">
    <Avatar variant="user" identifier={(user.email || '').charAt(0)} size="big" />
    <Typography variant="body" color="grey700">
      {user.email}
    </Typography>
  </div>
)

const getRolesColumn = (getDisplayName: (role: AllowedElements) => string) =>
  function RolesColumnInside({ roles }: Membership) {
    return <Chip label={getDisplayName({ name: roles[0] })} />
  }

const MemberList = () => {
  const { translate } = useInternationalization()
  const { members, metadata, membersLoading, membersFetchMore, membersError, membersRefetch } =
    useGetMembersList()
  const { hasPermissions } = usePermissions()
  const { currentUser } = useCurrentUser()
  const { getDisplayName } = useRoleDisplayInformation()

  const RolesColumn = getRolesColumn(getDisplayName)

  const [searchParams] = useSearchParams()

  const { openRevokeMembershipDialog } = useRevokeMembershipDialog()
  const { openEditMemberRoleDialog } = useEditMemberRoleDialog()
  const { openCreateInviteDialog } = useCreateInviteDialog()

  const selectedRole = useMemo(() => {
    return searchParams.get(MEMBERS_PAGE_ROLE_FILTER_KEY)
  }, [searchParams])

  const [searchQuery, setSearchQuery] = useState('')

  const filteredMembers = useMemo(() => {
    if (!selectedRole && !searchQuery) return members

    return members.filter((member) => {
      const matchesRole = !selectedRole || member.roles.includes(selectedRole)
      const matchesSearch =
        !searchQuery || member.user.email?.toLowerCase().includes(searchQuery.toLowerCase())

      return matchesRole && matchesSearch
    })
  }, [members, selectedRole, searchQuery])

  const handleInfiniteScrolling = () => {
    const { currentPage = 0, totalPages = 0 } = metadata || {}

    currentPage < totalPages &&
      !membersLoading &&
      membersFetchMore({
        variables: { page: currentPage + 1 },
      })
  }

  const columns: Array<TableColumn<Membership> | null> = [
    {
      key: 'user.email',
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

  const actionColumn: ActionColumn<Membership> = (membership) => {
    if (
      !hasPermissions(['organizationMembersUpdate']) &&
      !hasPermissions(['organizationMembersDelete'])
    ) {
      return undefined
    }

    const isCurrentUser = membership.user.id === currentUser?.id

    const editAction = hasPermissions(['organizationMembersUpdate'])
      ? [
          {
            startIcon: 'pen',
            title: translate('text_664f035a68227f00e261b7f6'),
            onAction: () => {
              openEditMemberRoleDialog({
                member: membership,
                isEditingLastAdmin: membership.roles[0] === 'Admin' && metadata?.adminCount === 1,
                isEditingMyOwnMembership: currentUser?.id === membership.user.id,
              })
            },
          } as ActionItem<MembershipItemForMembershipSettingsFragment>,
        ]
      : []

    const deleteAction =
      hasPermissions(['organizationMembersDelete']) && !isCurrentUser
        ? [
            {
              startIcon: 'trash',
              title: translate('text_63ea0f84f400488553caa786'),
              onAction: () => {
                const admins = members.filter((m) => m.roles.includes('Admin'))
                const isDeletingLastAdmin =
                  admins.some((admin) => admin.id === membership.id) && admins.length === 1

                openRevokeMembershipDialog({
                  id: membership.id,
                  email: membership.user.email || '',
                  organizationName: membership.organization?.name || '',
                  isDeletingLastAdmin,
                })
              },
            } as ActionItem<MembershipItemForMembershipSettingsFragment>,
          ]
        : []

    return [...editAction, ...deleteAction]
  }

  const tablePlaceholder = {
    emptyState: {
      title: translate('text_176771435162557p8hyixafi'),
      subtitle: translate('text_1767714241102xpwokcuhvki'),
      buttonTitle: translate('text_63208b630aaf8df6bbfb265b'),
      buttonAction: openCreateInviteDialog,
    },
    errorState: {
      title: translate('text_6321a076b94bd1b32494e9ee'),
      subtitle: translate('text_6321a076b94bd1b32494e9f0'),
      buttonTitle: translate('text_6321a076b94bd1b32494e9f2'),
      buttonAction: () => {
        membersRefetch()
      },
    },
  }

  return (
    <div>
      <MembersFilters searchQuery={searchQuery} setSearchQuery={setSearchQuery} type="members" />
      <InfiniteScroll onBottom={handleInfiniteScrolling}>
        <Table
          name="members-setting-members-list"
          containerSize={{ default: 0 }}
          rowSize={72}
          isLoading={membersLoading}
          data={filteredMembers}
          hasError={!!membersError}
          placeholder={tablePlaceholder}
          columns={columns}
          actionColumnTooltip={() => translate('text_626162c62f790600f850b7b6')}
          actionColumn={actionColumn}
        />
      </InfiniteScroll>
    </div>
  )
}

export default MemberList
