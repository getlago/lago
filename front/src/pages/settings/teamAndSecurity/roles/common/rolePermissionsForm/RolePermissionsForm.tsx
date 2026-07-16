import { type FieldGroupApi, GroupedCheckboxList } from '~/components/form'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withFieldGroup } from '~/hooks/forms/useAppform'

import { rolePermissionsEmptyValues } from './const'

import { useRolePermissionsGroups } from '../../hooks/useRolePermissionsGroups'
import { PermissionName } from '../permissionsTypes'

type RolePermissionsFormProps = {
  isEditable?: boolean
  isLoading?: boolean
  errors?: Array<string>
}

const defaultProps: RolePermissionsFormProps = {
  isEditable: true,
  isLoading: false,
  errors: [],
}

type PermissionValues = Record<PermissionName, boolean>

const RolePermissionsForm = withFieldGroup({
  defaultValues: rolePermissionsEmptyValues,
  props: defaultProps,
  render: function Render({ group, isEditable, isLoading, errors }) {
    const { translate } = useInternationalization()
    const { groups } = useRolePermissionsGroups()

    // Cast to FieldGroupApi - the TanStack Form group API is structurally compatible
    // but has more complex generic types that don't align directly
    const typedGroup = group as unknown as FieldGroupApi<PermissionValues>

    return (
      <GroupedCheckboxList
        group={typedGroup}
        title={translate('text_17670124237009cpv09qihgr')}
        subtitle={translate('text_17658096048119hpdp8kwcqd')}
        searchPlaceholder={translate('text_17670163638877x7zsoijho9')}
        groups={groups}
        isEditable={isEditable}
        isLoading={isLoading}
        errors={errors}
        errorScrollTarget="role-permissions-form-errors"
      />
    )
  },
})

export default RolePermissionsForm
