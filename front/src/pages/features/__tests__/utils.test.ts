import { PrivilegeValueTypeEnum } from '~/generated/graphql'

import { findFirstPrivilegeIndexWithDuplicateCode } from '../utils'

describe('findFirstPrivilegeIndexWithDuplicateCode', () => {
  it('should return the index of the first privilege with a duplicate code', () => {
    const privileges = [
      { code: 'privilege1', config: {}, id: '1', valueType: PrivilegeValueTypeEnum.Boolean },
      { code: 'privilege2', config: {}, id: '2', valueType: PrivilegeValueTypeEnum.String },
      { code: 'privilege1', config: {}, id: '3', valueType: PrivilegeValueTypeEnum.String },
      { code: 'privilege3', config: {}, id: '4', valueType: PrivilegeValueTypeEnum.String },
    ]
    const result1 = findFirstPrivilegeIndexWithDuplicateCode(privileges)

    expect(result1).toBe(2)

    const privileges2 = [
      { code: 'privilege1', config: {}, id: '1', valueType: PrivilegeValueTypeEnum.Boolean },
      { code: 'privilege2', config: {}, id: '2', valueType: PrivilegeValueTypeEnum.String },
      { code: 'privilege3', config: {}, id: '3', valueType: PrivilegeValueTypeEnum.String },
    ]
    const result2 = findFirstPrivilegeIndexWithDuplicateCode(privileges2)

    expect(result2).toBe(-1)
  })
})
