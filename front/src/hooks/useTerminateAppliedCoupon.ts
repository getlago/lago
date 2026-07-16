import { gql } from '@apollo/client'

import { addToast } from '~/core/apolloClient'
import { useRemoveCouponMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  mutation removeCoupon($input: TerminateAppliedCouponInput!) {
    terminateAppliedCoupon(input: $input) {
      id
    }
  }
`
type UseTerminateAppliedCouponResult = {
  terminateCoupon: (appliedCouponId: string) => Promise<void>
}

export const useTerminateAppliedCoupon = (): UseTerminateAppliedCouponResult => {
  const { translate } = useInternationalization()

  const [terminateAppliedCoupon] = useRemoveCouponMutation({
    onCompleted({ terminateAppliedCoupon: result }) {
      if (!!result) {
        addToast({
          severity: 'success',
          message: translate('text_628b8c693e464200e00e49d1'),
        })
      }
    },
    refetchQueries: ['getAppliedCouponsForCustomer', 'getAppliedCouponsForCouponDetails'],
  })

  const terminateCoupon = async (appliedCouponId: string) => {
    await terminateAppliedCoupon({
      variables: { input: { id: appliedCouponId } },
    })
  }

  return { terminateCoupon }
}
