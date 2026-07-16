import { Icon } from 'lago-design-system'
import { generatePath, useParams } from 'react-router-dom'

import { ButtonLink } from '~/components/designSystem/ButtonLink'
import { Typography } from '~/components/designSystem/Typography'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { SettingsListItemLoadingSkeleton } from '~/components/layouts/Settings'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { MEMBERS_PAGE_ROLE_FILTER_KEY } from '~/core/constants/roles'
import { TEAM_AND_SECURITY_GROUP_ROUTE, TEAM_AND_SECURITY_TAB_ROUTE } from '~/core/router'
import { PremiumIntegrationTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { useRoleDisplayInformation } from '~/hooks/useRoleDisplayInformation'
import {
  teamAndSecurityGroupOptions,
  teamAndSecurityTabOptions,
} from '~/pages/settings/teamAndSecurity/common/teamAndSecurityConst'

import { useDeleteRoleDialog } from '../common/dialogs/DeleteRoleDialog'
import { mapPermissionsFromRole } from '../common/rolePermissionsForm/mappers/mapPermissionsFromRole'
import RolePermissionsForm from '../common/rolePermissionsForm/RolePermissionsForm'
import RoleTypeChip from '../common/RoleTypeChip'
import { useRoleActions } from '../hooks/useRoleActions'
import { useRoleDetails } from '../hooks/useRoleDetails'

export const ROLE_DETAILS_ACTIONS_DROPDOWN_TEST_ID = 'role-details-actions-dropdown'
export const ROLE_DETAILS_DUPLICATE_ACTION_TEST_ID = 'role-details-duplicate-action'
export const ROLE_DETAILS_EDIT_ACTION_TEST_ID = 'role-details-edit-action'
export const ROLE_DETAILS_DELETE_ACTION_TEST_ID = 'role-details-delete-action'

const RoleDetails = () => {
  const { translate } = useInternationalization()
  const { roleId } = useParams<string>()
  const { role, isLoadingRole, isSystem, canBeDuplicated, canBeEdited, canBeDeleted } =
    useRoleDetails({ roleId })
  const { getDisplayName, getDisplayDescription } = useRoleDisplayInformation()
  const { navigateToDuplicate, navigateToEdit } = useRoleActions()
  const { hasOrganizationPremiumAddon } = useOrganizationInfos()
  const hasPremiumAddon = hasOrganizationPremiumAddon(PremiumIntegrationTypeEnum.CustomRoles)

  const premiumWarningDialog = usePremiumWarningDialog()
  const { openDeleteRoleDialog } = useDeleteRoleDialog()

  const openPremiumDialog = () => {
    premiumWarningDialog.open()
  }

  const form = useAppForm({
    defaultValues: {
      permissions: mapPermissionsFromRole(role),
    },
  })

  if (!roleId) {
    return <div>Role ID is missing</div>
  }

  const displayName = getDisplayName(role)
  const displayDescription = getDisplayDescription(role)
  const rolesListRoute = generatePath(TEAM_AND_SECURITY_GROUP_ROUTE, {
    group: teamAndSecurityGroupOptions.roles,
  })
  const getMembersListPath = () => {
    const basePath = generatePath(TEAM_AND_SECURITY_TAB_ROUTE, {
      group: teamAndSecurityGroupOptions.members,
      tab: teamAndSecurityTabOptions.members,
    })

    return `${basePath}?${MEMBERS_PAGE_ROLE_FILTER_KEY}=${role?.name}`
  }

  return (
    <>
      <MainHeader.Configure
        breadcrumb={[
          {
            label: translate('text_1765448879791epmkg4xijkn'),
            path: rolesListRoute,
          },
        ]}
        entity={{
          viewName: displayName || '',
          viewNameLoading: isLoadingRole,
          metadata: role?.code || '',
          metadataLoading: isLoadingRole,
        }}
        actions={{
          items: [
            {
              type: 'dropdown',
              label: translate('text_634687079be251fdb438338f'),
              dataTest: ROLE_DETAILS_ACTIONS_DROPDOWN_TEST_ID,
              items: [
                {
                  label: translate('text_64fa170e02f348164797a6af'),
                  dataTest: ROLE_DETAILS_DUPLICATE_ACTION_TEST_ID,
                  onClick: (closePopper) => {
                    if (!hasPremiumAddon) {
                      openPremiumDialog()
                    } else {
                      navigateToDuplicate(roleId)
                    }
                    closePopper()
                  },
                  disabled: hasPremiumAddon ? !canBeDuplicated : false,
                  endIcon: !hasPremiumAddon ? 'sparkles' : undefined,
                },
                {
                  label: translate('text_63aa15caab5b16980b21b0b8'),
                  dataTest: ROLE_DETAILS_EDIT_ACTION_TEST_ID,
                  onClick: (closePopper) => {
                    navigateToEdit(roleId)
                    closePopper()
                  },
                  disabled: !canBeEdited,
                  hidden: isSystem || !hasPremiumAddon,
                },
                {
                  label: translate('text_6261640f28a49700f1290df5'),
                  dataTest: ROLE_DETAILS_DELETE_ACTION_TEST_ID,
                  onClick: (closePopper) => {
                    if (role) openDeleteRoleDialog(role)
                    closePopper()
                  },
                  disabled: !canBeDeleted,
                  hidden: isSystem || !hasPremiumAddon,
                  danger: true,
                  tooltip: !canBeDeleted ? translate('text_1767002012431la8gv2iqucp') : undefined,
                },
              ],
            },
          ],
          loading: isLoadingRole,
        }}
      />
      <DetailsPage.Container className="max-w-192">
        <div className="flex flex-col gap-8">
          {isLoadingRole && <SettingsListItemLoadingSkeleton count={2} />}

          {!isLoadingRole && (
            <>
              <div className="flex flex-col gap-6">
                <Typography variant="subhead1">
                  {translate('text_1767012423699qiisp5z4jqy')}
                </Typography>
                <div className="flex flex-col gap-4">
                  <div>
                    <Typography variant="caption">
                      {translate('text_6388b923e514213fed58331c')}
                    </Typography>
                    <Typography color="grey700">{displayDescription}</Typography>
                  </div>
                  <div className="flex flex-row gap-8">
                    <div className="flex flex-1 flex-col">
                      <Typography variant="caption">
                        {translate('text_17654644170188lrzkfyhtkf')}
                      </Typography>
                      <RoleTypeChip role={role} />
                    </div>
                    <div className="flex flex-1 flex-col">
                      <Typography variant="caption">
                        {translate('text_1765464417018n3moulidii0')}
                      </Typography>
                      <ButtonLink
                        type="button"
                        to={getMembersListPath()}
                        external
                        buttonProps={{ variant: 'inline' }}
                      >
                        <div className="flex flex-row items-center gap-2">
                          {role?.memberships.length || 0}
                          <Icon name="outside" />
                        </div>
                      </ButtonLink>
                    </div>
                  </div>
                </div>
              </div>
              <RolePermissionsForm
                form={form}
                fields="permissions"
                isEditable={false}
                isLoading={isLoadingRole}
              />
            </>
          )}
        </div>
      </DetailsPage.Container>
    </>
  )
}

export default RoleDetails
