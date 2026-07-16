import { StatusType } from '~/components/designSystem/Status'
import { StatusTypeEnum } from '~/generated/graphql'

import { subscriptionStatusMapping } from '../statusSubscriptionMapping'

describe('subscriptionStatusMapping', () => {
  describe('GIVEN a known subscription status', () => {
    it.each([
      [StatusTypeEnum.Active, StatusType.success, 'active'],
      [StatusTypeEnum.Pending, StatusType.default, 'pending'],
      [StatusTypeEnum.Incomplete, StatusType.warning, 'incomplete'],
      [StatusTypeEnum.Canceled, StatusType.disabled, 'canceled'],
      [StatusTypeEnum.Terminated, StatusType.danger, 'terminated'],
    ])('THEN should map %s to the matching type and label', (status, type, label) => {
      expect(subscriptionStatusMapping(status)).toEqual({ type, label })
    })
  })

  describe('GIVEN no status', () => {
    it.each([[null], [undefined]])(
      'THEN should fall back to the pending default for %s',
      (status) => {
        expect(subscriptionStatusMapping(status)).toEqual({
          type: StatusType.default,
          label: 'pending',
        })
      },
    )
  })
})
