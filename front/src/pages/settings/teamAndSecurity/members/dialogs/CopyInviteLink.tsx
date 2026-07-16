import { useMemo } from 'react'
import { generatePath } from 'react-router-dom'

import { Typography } from '~/components/designSystem/Typography'
import { INVITATION_ROUTE } from '~/core/router'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useRoleDisplayInformation } from '~/hooks/useRoleDisplayInformation'
import { useRolesList } from '~/hooks/useRolesList'

import { INVITE_URL_DATA_TEST } from './CreateInviteDialog'

type CopyInviteLinkProps = {
  email: string
  role: string
  inviteToken: string
}

const CopyInviteLink = ({ email, role, inviteToken }: CopyInviteLinkProps) => {
  const { getDisplayName } = useRoleDisplayInformation()
  const { roles } = useRolesList()
  const { translate } = useInternationalization()

  const invitationUrl = `${globalThis.location.origin}${generatePath(INVITATION_ROUTE, {
    token: inviteToken,
  })}`

  const roleToDisplay = useMemo(() => {
    return roles.find((r) => r.code === role)
  }, [roles, role])

  return (
    <div className="flex flex-col gap-6 p-8">
      <div className="flex items-baseline">
        <Typography className="w-35 shrink-0" variant="caption" color="grey600">
          {translate('text_63208c701ce25db781407458')}
        </Typography>
        <Typography variant="body" color="grey700" noWrap>
          {email}
        </Typography>
      </div>
      <div className="flex items-baseline">
        <Typography className="w-35 shrink-0" variant="caption" color="grey600">
          {translate('text_664f035a68227f00e261b7ec')}
        </Typography>
        {roleToDisplay && (
          <Typography variant="body" color="grey700" noWrap>
            {getDisplayName(roleToDisplay)}
          </Typography>
        )}
      </div>
      <div className="flex items-baseline">
        <Typography className="w-35 shrink-0" variant="caption" color="grey600">
          {translate('text_63208c701ce25db781407475')}
        </Typography>
        <Typography
          className="line-break-anywhere"
          variant="body"
          color="grey700"
          data-test={INVITE_URL_DATA_TEST}
        >
          {invitationUrl}
        </Typography>
      </div>
    </div>
  )
}

export default CopyInviteLink
