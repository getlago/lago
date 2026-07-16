import { gql } from '@apollo/client'
import { generatePath } from 'react-router-dom'

import { CouponCaption } from '~/components/coupons/CouponCaption'
import { APPLIED_COUPON_STATUS_CONFIG } from '~/components/coupons/utils'
import { computeCustomerInitials } from '~/components/customers/utils'
import { Avatar } from '~/components/designSystem/Avatar'
import { Button } from '~/components/designSystem/Button'
import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { Status } from '~/components/designSystem/Status'
import { Table, TableColumn } from '~/components/designSystem/Table/Table'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { CustomerDetailsTabsOptions } from '~/core/constants/tabsOptions'
import { CUSTOMER_DETAILS_TAB_ROUTE } from '~/core/router'
import { intlFormatDateTime } from '~/core/timezone'
import {
  AppliedCouponCaptionFragmentDoc,
  AppliedCouponStatusEnum,
  useGetAppliedCouponsForCouponDetailsQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { usePermissions } from '~/hooks/usePermissions'
import { useTerminateAppliedCoupon } from '~/hooks/useTerminateAppliedCoupon'

gql`
  query getAppliedCouponsForCouponDetails($page: Int, $limit: Int, $couponCode: [String!]) {
    appliedCoupons(page: $page, limit: $limit, couponCode: $couponCode) {
      metadata {
        currentPage
        totalPages
      }
      collection {
        id
        status
        ...AppliedCouponCaption
        createdAt
        terminatedAt
        coupon {
          id
          name
          code
        }
        customer {
          id
          name
          displayName
          externalId
        }
      }
    }
  }

  ${AppliedCouponCaptionFragmentDoc}
`

interface CouponDetailsAppliedCouponsProps {
  couponCode?: string
}

export const CouponDetailsAppliedCoupons = ({ couponCode }: CouponDetailsAppliedCouponsProps) => {
  const { translate } = useInternationalization()
  const { hasPermissions } = usePermissions()
  const { terminateCoupon } = useTerminateAppliedCoupon()
  const centralizedDialog = useCentralizedDialog()

  const { data, loading, error, fetchMore } = useGetAppliedCouponsForCouponDetailsQuery({
    variables: { couponCode: couponCode ? [couponCode] : undefined, limit: 20 },
    skip: !couponCode,
    notifyOnNetworkStatusChange: true,
    fetchPolicy: 'network-only',
  })

  const appliedCoupons = data?.appliedCoupons?.collection || []

  const columns: Array<TableColumn<(typeof appliedCoupons)[number]>> = [
    {
      key: 'status',
      minWidth: 90,
      title: translate('text_1772536695408q802eishgnx'),
      content: ({ status }) => {
        const config = APPLIED_COUPON_STATUS_CONFIG[status]

        return (
          <div className="pl-1">
            <Status type={config.type} label={translate(config.label)} />
          </div>
        )
      },
    },
    {
      key: 'customer.name',
      title: translate('text_624efab67eb2570101d117be'),
      maxSpace: true,
      minWidth: 340,
      maxWidth: 600,
      content: ({ customer }) => {
        const customerName = customer?.displayName
        const customerInitials = computeCustomerInitials(customer)

        return (
          <div className="flex items-center gap-3">
            <Avatar
              size="big"
              variant="user"
              identifier={customerName as string}
              initials={customerInitials}
            />
            <div className="flex flex-col">
              <Typography variant="bodyHl" color="textSecondary" noWrap>
                {customerName}
              </Typography>
              <TypographyWithCopy variant="caption" color="grey600" noWrap>
                {customer?.externalId ?? ''}
              </TypographyWithCopy>
            </div>
          </div>
        )
      },
    },
    {
      key: 'amountCurrency',
      title: translate('text_632d68358f1fedc68eed3e9d'),
      content: (appliedCoupon) => (
        <CouponCaption
          variant="subhead2"
          className="text-nowrap text-grey-600"
          coupon={appliedCoupon}
        />
      ),
    },
    {
      key: 'createdAt',
      title: translate('text_1741943835752e00705sjtf8'),
      minWidth: 150,
      content: ({ createdAt }) => (
        <Typography variant="body" color="grey700">
          {intlFormatDateTime(createdAt).date}
        </Typography>
      ),
    },
  ]

  const getRowActionLink = (appliedCoupon: (typeof appliedCoupons)[number]) =>
    generatePath(CUSTOMER_DETAILS_TAB_ROUTE, {
      customerId: appliedCoupon.customer.id,
      tab: CustomerDetailsTabsOptions.overview,
    })

  const actionColumn = (appliedCoupon: (typeof appliedCoupons)[number]) =>
    hasPermissions(['couponsDetach']) &&
    appliedCoupon.status === AppliedCouponStatusEnum.Active && (
      <Tooltip
        className="ml-auto pr-1"
        placement="top-end"
        title={translate('text_628b8c693e464200e00e4a10')}
      >
        <Button
          variant="quaternary"
          icon="trash"
          onClick={() => {
            centralizedDialog.open({
              title: translate('text_628b8c693e464200e00e465f'),
              description: translate('text_628b8c693e464200e00e466d'),
              colorVariant: 'danger',
              actionText: translate('text_628b8c693e464200e00e4689'),
              onAction: async () => {
                await terminateCoupon(appliedCoupon.id)
              },
            })
          }}
        />
      </Tooltip>
    )

  const fetchNextPage = () => {
    const { currentPage = 0, totalPages = 0 } = data?.appliedCoupons?.metadata || {}

    currentPage < totalPages &&
      !loading &&
      fetchMore({
        variables: { page: currentPage + 1 },
      })
  }

  return (
    <section>
      <DetailsPage.SectionTitle variant="subhead1" noWrap>
        {translate('text_62865498824cc10126ab2956')}
      </DetailsPage.SectionTitle>

      <InfiniteScroll onBottom={fetchNextPage}>
        <Table
          name="coupon-details-applied-coupons"
          data={appliedCoupons}
          containerSize={0}
          isLoading={loading}
          hasError={!!error}
          rowSize={72}
          onRowActionLink={getRowActionLink}
          placeholder={{
            emptyState: {
              title: translate('text_17744725308411jbq4fvqqbm'),
              subtitle: translate('text_1774472532373ewcnm51b2ms'),
            },
          }}
          columns={columns}
          actionColumn={actionColumn}
        />
      </InfiniteScroll>
    </section>
  )
}
