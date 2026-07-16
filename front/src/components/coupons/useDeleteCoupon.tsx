import { gql } from '@apollo/client'

import { Typography } from '~/components/designSystem/Typography'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { useDeleteCouponMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment DeleteCoupon on Coupon {
    id
    name
    appliedCouponsCount
  }

  mutation deleteCoupon($input: DestroyCouponInput!) {
    destroyCoupon(input: $input) {
      id
    }
  }
`

type DeleteCouponDialogParams = {
  couponId: string
  couponName: string
  appliedCouponsCount: number
  callback?: () => void
}

export const useDeleteCoupon = () => {
  const { translate } = useInternationalization()
  const dialog = useCentralizedDialog()
  const [deleteCoupon] = useDeleteCouponMutation({
    onCompleted(data) {
      if (data?.destroyCoupon) {
        addToast({
          message: translate('text_628b432fd8f2bc0105b9746f'),
          severity: 'success',
        })
      }
    },
    refetchQueries: ['coupons'],
  })

  const openDialog = ({
    couponId,
    couponName,
    appliedCouponsCount,
    callback,
  }: DeleteCouponDialogParams) => {
    const description = appliedCouponsCount ? (
      <Typography
        html={translate(
          'text_17364422965884zgujkr1l7j',
          { appliedCouponsCount },
          appliedCouponsCount,
        )}
      />
    ) : (
      <Typography html={translate('text_628b432fd8f2bc0105b973f6')} />
    )

    const onAction = async () => {
      await deleteCoupon({
        variables: { input: { id: couponId } },
      })

      callback?.()

      return { reason: 'success' } as const
    }

    dialog.open({
      title: translate('text_628b432fd8f2bc0105b973ee', { couponName }),
      description,
      colorVariant: 'danger',
      actionText: translate('text_628b432fd8f2bc0105b97406'),
      onAction,
    })
  }

  return { openDialog }
}
