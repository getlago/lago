import { gql } from '@apollo/client'
import { generatePath, useParams } from 'react-router-dom'

import { CouponDetailsActivityLogs } from '~/components/coupons/CouponDetailsActivityLogs'
import { CouponDetailsAppliedCoupons } from '~/components/coupons/CouponDetailsAppliedCoupons'
import { CouponDetailsOverview } from '~/components/coupons/CouponDetailsOverview'
import { useDeleteCoupon } from '~/components/coupons/useDeleteCoupon'
import { useTerminateCoupon } from '~/components/coupons/useTerminateCoupon'
import { formatCouponValue } from '~/components/coupons/utils'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { MainHeaderAction } from '~/components/MainHeader/types'
import { useMainHeaderTabContent } from '~/components/MainHeader/useMainHeaderTabContent'
import { CouponDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  COUPON_DETAILS_ROUTE,
  COUPONS_ROUTE,
  UPDATE_COUPON_ROUTE,
  useNavigate,
} from '~/core/router'
import {
  DeleteCouponFragmentDoc,
  LagoApiError,
  TerminateCouponFragmentDoc,
  useGetCouponForDetailsQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useNotFoundRedirect } from '~/hooks/useNotFoundRedirect'
import { usePermissions } from '~/hooks/usePermissions'
import { usePermissionsCouponActions } from '~/hooks/usePermissionsCouponActions'

gql`
  fragment CouponDetailsForHeader on Coupon {
    name
    code
    status
    couponType
    percentageRate
    amountCents
    amountCurrency
    frequency
  }

  query getCouponForDetails($id: ID!) {
    coupon(id: $id) {
      id
      ...CouponDetailsForHeader
      ...DeleteCoupon
      ...TerminateCoupon
    }
  }

  ${DeleteCouponFragmentDoc}
  ${TerminateCouponFragmentDoc}
`

const CouponDetails = () => {
  const navigate = useNavigate()
  const { translate } = useInternationalization()
  const { couponId } = useParams()
  const { isPremium } = useCurrentUser()
  const { hasPermissions } = usePermissions()
  const couponActions = usePermissionsCouponActions()
  const { openDialog: openDeleteDialog } = useDeleteCoupon()
  const { openDialog: openTerminateDialog } = useTerminateCoupon()

  const { data, loading, error } = useGetCouponForDetailsQuery({
    variables: {
      id: couponId as string,
    },
    skip: !couponId,
    context: { silentErrorCodes: [LagoApiError.NotFound] },
  })

  useNotFoundRedirect({
    error,
    loading,
    redirectTo: COUPONS_ROUTE,
    translateKey: 'text_1777995443788jkq4zx3m74e',
  })

  const coupon = data?.coupon

  const actions: MainHeaderAction[] = [
    {
      type: 'dropdown',
      label: translate('text_626162c62f790600f850b6fe'),
      dataTest: 'coupon-details-actions',
      items: [
        {
          label: translate('text_625fd39a15394c0117e7d792'),
          dataTest: 'coupon-details-edit',
          hidden: !couponActions.canEdit(),
          onClick: (closePopper) => {
            navigate(generatePath(UPDATE_COUPON_ROUTE, { couponId: couponId as string }))
            closePopper()
          },
        },
        {
          label: translate('text_62876a50ea3bba00b56d2cbc'),
          hidden: !coupon || !couponActions.canTerminate(coupon),
          onClick: (closePopper) => {
            if (coupon) openTerminateDialog({ id: coupon.id, name: coupon.name })
            closePopper()
          },
        },
        {
          label: translate('text_629728388c4d2300e2d38182'),
          hidden: !coupon || !couponActions.canDelete(),
          dataTest: 'coupon-details-delete',
          onClick: (closePopper) => {
            if (!coupon) return

            openDeleteDialog({
              couponId: coupon.id,
              couponName: coupon.name,
              appliedCouponsCount: coupon.appliedCouponsCount,
              callback: () => {
                navigate(COUPONS_ROUTE)
              },
            })
            closePopper()
          },
        },
      ],
    },
  ]

  const activeTabContent = useMainHeaderTabContent()

  return (
    <>
      <MainHeader.Configure
        breadcrumb={[{ label: translate('text_62865498824cc10126ab2956'), path: COUPONS_ROUTE }]}
        entity={{
          viewName: coupon?.name || '',
          viewNameLoading: loading,
          metadata: `${formatCouponValue({
            couponType: coupon?.couponType,
            percentageRate: coupon?.percentageRate,
            amountCents: coupon?.amountCents,
            amountCurrency: coupon?.amountCurrency,
          })} ${coupon?.frequency}`,
          metadataLoading: loading,
        }}
        actions={{ items: actions, loading }}
        tabs={[
          {
            title: translate('text_628cf761cbe6820138b8f2e4'),
            link: generatePath(COUPON_DETAILS_ROUTE, {
              couponId: couponId as string,
              tab: CouponDetailsTabsOptionsEnum.overview,
            }),
            content: (
              <DetailsPage.Container>
                <CouponDetailsOverview />
              </DetailsPage.Container>
            ),
          },
          {
            title: translate('text_624efab67eb2570101d117a5'),
            link: generatePath(COUPON_DETAILS_ROUTE, {
              couponId: couponId as string,
              tab: CouponDetailsTabsOptionsEnum.appliedCoupons,
            }),
            content: (
              <DetailsPage.Container>
                <CouponDetailsAppliedCoupons couponCode={coupon?.code || undefined} />
              </DetailsPage.Container>
            ),
          },
          {
            title: translate('text_1747314141347qq6rasuxisl'),
            link: generatePath(COUPON_DETAILS_ROUTE, {
              couponId: couponId as string,
              tab: CouponDetailsTabsOptionsEnum.activityLogs,
            }),
            content: (
              <DetailsPage.Container>
                <CouponDetailsActivityLogs couponId={couponId as string} />
              </DetailsPage.Container>
            ),
            hidden: !isPremium || !hasPermissions(['auditLogsView']),
          },
        ]}
      />

      <>{activeTabContent}</>
    </>
  )
}

export default CouponDetails
