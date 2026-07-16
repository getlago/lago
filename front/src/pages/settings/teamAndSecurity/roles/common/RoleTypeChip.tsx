import { Status, StatusType } from '~/components/designSystem/Status'
import { RoleItem, systemRoles } from '~/core/constants/roles'
import { useInternationalization } from '~/hooks/core/useInternationalization'

type RoleTypeChipProps = {
  role?: RoleItem
}

const RoleTypeChip = ({ role }: RoleTypeChipProps) => {
  const { translate } = useInternationalization()

  if (!role) {
    return null
  }

  const roleType = systemRoles.includes(role.name)
    ? translate('text_1765464506554l3g5v7dctfv')
    : translate('text_6641dd21c0cffd005b5e2a8b')

  return <Status label={roleType} type={StatusType.default} />
}

export default RoleTypeChip
