import { PrivilegeObject } from '~/generated/graphql'

export const findFirstPrivilegeIndexWithDuplicateCode = (privileges: PrivilegeObject[]) => {
  return privileges.findLastIndex((privilege, index) =>
    privileges.some((p, i) => {
      return p.code === privilege.code && i !== index
    }),
  )
}
