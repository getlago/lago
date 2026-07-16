import { generatePath } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { NavigationTab } from '~/components/designSystem/NavigationTab'
import {
  SettingsListItem,
  SettingsListItemHeader,
  SettingsListWrapper,
  SettingsWithTabsPaddedContainer,
} from '~/components/layouts/Settings'
import { TEAM_AND_SECURITY_GROUP_ROUTE, TEAM_AND_SECURITY_TAB_ROUTE } from '~/core/router'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { useCreateInviteDialog } from './dialogs/CreateInviteDialog'
import MembersInvitationList from './MembersInvitationList'
import MembersList from './MembersList'

import {
  teamAndSecurityGroupOptions,
  teamAndSecurityTabOptions,
} from '../common/teamAndSecurityConst'

const Members = () => {
  const { translate } = useInternationalization()
  const { openCreateInviteDialog } = useCreateInviteDialog()

  return (
    <SettingsWithTabsPaddedContainer>
      <SettingsListWrapper>
        <SettingsListItem className="[box-shadow:none]">
          <SettingsListItemHeader
            label={translate('text_63208b630aaf8df6bbfb2657')}
            sublabel={translate('text_63208b630aaf8df6bbfb2659')}
            action={
              <Button
                variant="inline"
                onClick={openCreateInviteDialog}
                data-test="create-invite-button"
              >
                {translate('text_63208b630aaf8df6bbfb265b')}
              </Button>
            }
          />
          <NavigationTab
            tabs={[
              {
                title: translate('text_63208b630aaf8df6bbfb2655'),
                match: [
                  generatePath(TEAM_AND_SECURITY_GROUP_ROUTE, {
                    group: teamAndSecurityGroupOptions.members,
                  }),
                  generatePath(TEAM_AND_SECURITY_TAB_ROUTE, {
                    group: teamAndSecurityGroupOptions.members,
                    tab: teamAndSecurityTabOptions.members,
                  }),
                ],
                link: generatePath(TEAM_AND_SECURITY_TAB_ROUTE, {
                  group: teamAndSecurityGroupOptions.members,
                  tab: teamAndSecurityTabOptions.members,
                }),
                component: <MembersList />,
              },
              {
                title: translate('text_1728310120853rutc5q05ax6'),
                link: generatePath(TEAM_AND_SECURITY_TAB_ROUTE, {
                  group: teamAndSecurityGroupOptions.members,
                  tab: teamAndSecurityTabOptions.invitations,
                }),
                component: <MembersInvitationList />,
              },
            ]}
          />
        </SettingsListItem>
      </SettingsListWrapper>
    </SettingsWithTabsPaddedContainer>
  )
}

export default Members
