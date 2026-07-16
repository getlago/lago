import { useEffect, useMemo } from 'react'
import { generatePath, matchPath } from 'react-router-dom'

import { MainHeader } from '~/components/MainHeader/MainHeader'
import { useMainHeaderTabContent } from '~/components/MainHeader/useMainHeaderTabContent'
import {
  TEAM_AND_SECURITY_GROUP_ROUTE,
  TEAM_AND_SECURITY_ROOT_ROUTE,
  TEAM_AND_SECURITY_TAB_ROUTE,
  useLocation,
  useNavigate,
} from '~/core/router'
import { PremiumIntegrationTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { usePermissions } from '~/hooks/usePermissions'

import Authentication from './authentication/Authentication'
import {
  teamAndSecurityGroupOptions,
  teamAndSecurityTabOptions,
} from './common/teamAndSecurityConst'
import Members from './members/Members'
import RolesList from './roles/rolesList/RolesList'
import SecurityLogs from './securityLogs/SecurityLogs'

const TeamAndSecurity = () => {
  const { translate } = useInternationalization()
  const { hasPermissions } = usePermissions()
  const navigate = useNavigate()
  const { strippedPathname: pathname } = useLocation()
  const { hasOrganizationPremiumAddon } = useOrganizationInfos()

  const tabs = useMemo(
    () => [
      {
        title: translate('text_63208b630aaf8df6bbfb2655'),
        match: [
          TEAM_AND_SECURITY_ROOT_ROUTE,
          generatePath(TEAM_AND_SECURITY_GROUP_ROUTE, {
            group: teamAndSecurityGroupOptions.members,
          }),
          generatePath(TEAM_AND_SECURITY_TAB_ROUTE, {
            group: teamAndSecurityGroupOptions.members,
            tab: teamAndSecurityTabOptions.members,
          }),
          generatePath(TEAM_AND_SECURITY_TAB_ROUTE, {
            group: teamAndSecurityGroupOptions.members,
            tab: teamAndSecurityTabOptions.invitations,
          }),
        ],
        link: generatePath(TEAM_AND_SECURITY_GROUP_ROUTE, {
          group: teamAndSecurityGroupOptions.members,
        }),
        content: <Members />,
        hidden: !hasPermissions(['organizationMembersView']),
      },
      {
        title: translate('text_1765448879791epmkg4xijkn'),
        match: [
          generatePath(TEAM_AND_SECURITY_GROUP_ROUTE, {
            group: teamAndSecurityGroupOptions.roles,
          }),
        ],
        link: generatePath(TEAM_AND_SECURITY_GROUP_ROUTE, {
          group: teamAndSecurityGroupOptions.roles,
        }),
        content: <RolesList />,
        hidden: !hasPermissions(['rolesView']),
      },
      {
        title: translate('text_664c732c264d7eed1c74fd96'),
        match: [
          generatePath(TEAM_AND_SECURITY_GROUP_ROUTE, {
            group: teamAndSecurityGroupOptions.authentication,
          }),
        ],
        link: generatePath(TEAM_AND_SECURITY_GROUP_ROUTE, {
          group: teamAndSecurityGroupOptions.authentication,
        }),
        content: <Authentication />,
        hidden: !hasPermissions(['authenticationMethodsView']),
      },
      {
        title: translate('text_1771855827236eqkaiznri70'),
        match: [
          generatePath(TEAM_AND_SECURITY_GROUP_ROUTE, {
            group: teamAndSecurityGroupOptions.logs,
          }),
        ],
        link: generatePath(TEAM_AND_SECURITY_GROUP_ROUTE, {
          group: teamAndSecurityGroupOptions.logs,
        }),
        content: <SecurityLogs />,
        hidden:
          !hasPermissions(['securityLogsView']) ||
          !hasOrganizationPremiumAddon(PremiumIntegrationTypeEnum.SecurityLogs),
      },
    ],
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [translate, hasPermissions],
  )

  // Redirect to first visible tab when landing on root or a hidden tab
  useEffect(() => {
    const isRootRoute = !!matchPath(TEAM_AND_SECURITY_ROOT_ROUTE, pathname)
    const isOnHiddenTab = tabs.some(
      (tab) => tab.hidden && tab.match.some((m) => matchPath(m, pathname)),
    )

    if (!isRootRoute && !isOnHiddenTab) return

    const firstVisibleTab = tabs.find((tab) => !tab.hidden)

    if (!firstVisibleTab?.link) return

    navigate(firstVisibleTab.link, { replace: true })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pathname, tabs])

  const tabContent = useMainHeaderTabContent()

  return (
    <>
      <MainHeader.Configure
        entity={{
          viewName: translate('text_177073440645951fhlh2ofdc'),
        }}
        tabs={tabs}
      />

      <>{tabContent}</>
    </>
  )
}

export default TeamAndSecurity
