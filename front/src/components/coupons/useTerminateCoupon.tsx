import { gql } from '@apollo/client'

import { Typography } from '~/components/designSystem/Typography'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import {
  GetCouponForDetailsOverviewDocument,
  useTerminateCouponMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment TerminateCoupon on Coupon {
    id
    name
  }

  mutation terminateCoupon($input: TerminateCouponInput!) {
    terminateCoupon(input: $input) {
      id
    }
  }
`

type TerminateCouponDialogParams = {
  id: string
  name: string
}

export const useTerminateCoupon = () => {
  const { translate } = useInternationalization()
  const dialog = useCentralizedDialog()
  const [terminateCoupon] = useTerminateCouponMutation({
    onCompleted(data) {
      if (data?.terminateCoupon) {
        addToast({
          message: translate('text_628b432fd8f2bc0105b9746a'),
          severity: 'success',
        })
      }
    },
    refetchQueries: ['coupons'],
  })

  const openDialog = (coupon: TerminateCouponDialogParams) => {
    const onAction = async () => {
      await terminateCoupon({
        variables: { input: { id: coupon.id } },
        refetchQueries: [
          'coupons',
          { query: GetCouponForDetailsOverviewDocument, variables: { id: coupon.id } },
        ],
      })

      return { reason: 'success' } as const
    }

    dialog.open({
      title: translate('text_628b432fd8f2bc0105b973ec', { couponName: coupon.name }),
      description: <Typography html={translate('text_628b432fd8f2bc0105b973f4')} />,
      colorVariant: 'danger',
      actionText: translate('text_628b432fd8f2bc0105b97404'),
      onAction,
    })
  }

  return { openDialog }
}
