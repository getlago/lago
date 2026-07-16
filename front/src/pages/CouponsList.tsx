import { gql } from '@apollo/client'
import { Icon, tw } from 'lago-design-system'
import { generatePath } from 'react-router-dom'

import { CouponCaption } from '~/components/coupons/CouponCaption'
import { useDeleteCoupon } from '~/components/coupons/useDeleteCoupon'
import { useTerminateCoupon } from '~/components/coupons/useTerminateCoupon'
import { Avatar } from '~/components/designSystem/Avatar'
import { GenericPlaceholderProps } from '~/components/designSystem/GenericPlaceholder'
import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { Status } from '~/components/designSystem/Status'
import { Table } from '~/components/designSystem/Table/Table'
import { ActionItem } from '~/components/designSystem/Table/types'
import { Typography } from '~/components/designSystem/Typography'
import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import { formatCountToMetadata } from '~/components/MainHeader/formatCountToMetadata'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { SearchInput } from '~/components/SearchInput'
import { couponStatusMapping } from '~/core/constants/statusCouponMapping'
import { CouponDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  COUPON_DETAILS_ROUTE,
  CREATE_COUPON_ROUTE,
  UPDATE_COUPON_ROUTE,
  useNavigate,
} from '~/core/router'
import {
  CouponCaptionFragmentDoc,
  CouponsQuery,
  DeleteCouponFragmentDoc,
  TerminateCouponFragmentDoc,
  useCouponsLazyQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useDebouncedSearch } from '~/hooks/useDebouncedSearch'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { usePermissionsCouponActions } from '~/hooks/usePermissionsCouponActions'

gql`
  fragment CouponItem on Coupon {
    id
    name
    code
    customersCount
    status
    amountCurrency
    amountCents
    expiration
    expirationAt
    couponType
    percentageRate
    frequency
    frequencyDuration
  }

  query coupons($page: Int, $limit: Int, $searchTerm: String) {
    coupons(page: $page, limit: $limit, searchTerm: $searchTerm) {
      metadata {
        currentPage
        totalPages
        totalCount
      }
      collection {
        ...CouponItem
        ...CouponCaption
        ...DeleteCoupon
        ...TerminateCoupon
      }
    }
  }

  ${CouponCaptionFragmentDoc}
  ${DeleteCouponFragmentDoc}
  ${TerminateCouponFragmentDoc}
`

type CouponItem = CouponsQuery['coupons']['collection'][number]

const CouponsList = () => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const { intlFormatDateTimeOrgaTZ } = useOrganizationInfos()
  const actions = usePermissionsCouponActions()
  const { openDialog: openDeleteDialog } = useDeleteCoupon()
  const { openDialog: openTerminateDialog } = useTerminateCoupon()
  const [getCoupons, { data, error, loading, fetchMore, variables }] = useCouponsLazyQuery({
    variables: { limit: 20 },
    notifyOnNetworkStatusChange: true,
    fetchPolicy: 'network-only',
    nextFetchPolicy: 'network-only',
  })
  const { debouncedSearch, isLoading } = useDebouncedSearch(getCoupons, loading)
  const list = data?.coupons?.collection || []

  const getEmptyState = (): Partial<GenericPlaceholderProps> => {
    if (variables?.searchTerm) {
      return {
        title: translate('text_63beebbf4f60e2f553232773'),
        subtitle: translate('text_63beebbf4f60e2f553232775'),
      }
    }
    if (actions.canCreate()) {
      return {
        title: translate('text_62865498824cc10126ab296c'),
        subtitle: translate('text_62865498824cc10126ab2971'),
        buttonTitle: translate('text_62865498824cc10126ab2975'),
        buttonVariant: 'primary',
        buttonAction: () => navigate(CREATE_COUPON_ROUTE),
      }
    }
    return {
      title: translate('text_664dec926bfdb6007a036b78'),
      subtitle: translate('text_62865498824cc10126ab2971'),
    }
  }

  const getActionsForActionsColumn = ({
    coupon,
  }: {
    coupon: CouponItem
  }): Array<ActionItem<CouponItem>> => {
    const result: Array<ActionItem<CouponItem>> = []

    if (actions.canEdit()) {
      result.push({
        startIcon: 'pen',
        title: translate('text_625fd39a15394c0117e7d792'),
        dataTest: 'edit-coupon',
        onAction: () => navigate(generatePath(UPDATE_COUPON_ROUTE, { couponId: coupon.id })),
      })
    }

    if (actions.canTerminate(coupon)) {
      result.push({
        startIcon: 'switch',
        title: translate('text_62876a50ea3bba00b56d2cbc'),
        dataTest: 'terminate-coupon',
        onAction: () => {
          openTerminateDialog({ id: coupon.id, name: coupon.name })
        },
      })
    }

    if (actions.canDelete()) {
      result.push({
        startIcon: 'trash',
        title: translate('text_629728388c4d2300e2d38182'),
        dataTest: 'delete-coupon',
        onAction: () => {
          openDeleteDialog({
            couponId: coupon.id,
            couponName: coupon.name,
            appliedCouponsCount: coupon.appliedCouponsCount,
          })
        },
      })
    }

    return result
  }

  const couponsTotalCount = data?.coupons?.metadata?.totalCount

  return (
    <>
      <MainHeader.Configure
        entity={{
          viewName: translate('text_62865498824cc10126ab2956'),
          metadata: formatCountToMetadata(couponsTotalCount, translate),
          metadataLoading: isLoading,
        }}
        actions={{
          items: [
            {
              type: 'action',
              label: translate('text_62865498824cc10126ab2954'),
              variant: 'primary',
              hidden: !actions.canCreate(),
              onClick: () => navigate(CREATE_COUPON_ROUTE),
              dataTest: 'add-coupon',
            },
          ],
        }}
        filtersSection={
          <SearchInput
            onChange={debouncedSearch}
            placeholder={translate('text_63beebbf4f60e2f553232782')}
          />
        }
      />

      <InfiniteScroll
        onBottom={() => {
          const { currentPage = 0, totalPages = 0 } = data?.coupons?.metadata || {}

          currentPage < totalPages &&
            !isLoading &&
            fetchMore({
              variables: { page: currentPage + 1 },
            })
        }}
      >
        <Table
          name="coupons-list"
          data={list}
          containerSize={{
            default: 16,
            md: 48,
          }}
          containerClassName={tw('h-[calc(100%-theme(space.nav))] border-t border-grey-300')}
          rowSize={72}
          isLoading={isLoading}
          hasError={!!error}
          onRowActionLink={({ id }) =>
            generatePath(COUPON_DETAILS_ROUTE, {
              couponId: id,
              tab: CouponDetailsTabsOptionsEnum.overview,
            })
          }
          rowDataTestId={(addOn) => `${addOn.name}`}
          columns={[
            {
              key: 'name',
              title: translate('text_62865498824cc10126ab2960'),
              minWidth: 200,
              maxSpace: true,
              content: (coupon) => (
                <div className="flex items-center gap-3">
                  <Avatar size="big" variant="connector">
                    <Icon name="coupon" color="dark" />
                  </Avatar>
                  <div>
                    <Typography color="textSecondary" variant="bodyHl" noWrap>
                      {coupon.name}
                    </Typography>
                    <div className="flex items-baseline gap-1">
                      <TypographyWithCopy className="shrink-0" compact noWrap variant="caption">
                        {coupon.code}
                      </TypographyWithCopy>
                      <Typography className="shrink-0" variant="caption" noWrap>
                        •
                      </Typography>
                      <CouponCaption coupon={coupon} variant="caption" />
                    </div>
                  </div>
                </div>
              ),
            },
            {
              key: 'customersCount',
              title: translate('text_62865498824cc10126ab2964'),
              textAlign: 'right',
              minWidth: 112,
              content: ({ customersCount }) => (
                <Typography color="grey600">{customersCount}</Typography>
              ),
            },
            {
              key: 'expirationAt',
              title: translate('text_62865498824cc10126ab296a'),
              minWidth: 140,
              content: ({ expirationAt }) => (
                <Typography color="grey600">
                  {!expirationAt
                    ? translate('text_62876a50ea3bba00b56d2c2c')
                    : intlFormatDateTimeOrgaTZ(expirationAt).date}
                </Typography>
              ),
            },
            {
              key: 'status',
              title: translate('text_62865498824cc10126ab296f'),
              minWidth: 80,
              content: ({ status }) => <Status {...couponStatusMapping(status)} />,
            },
          ]}
          actionColumnTooltip={() => translate('text_634687079be251fdb438338f')}
          actionColumn={(coupon) => getActionsForActionsColumn({ coupon })}
          placeholder={{
            errorState: !!variables?.searchTerm
              ? {
                  title: translate('text_623b53fea66c76017eaebb6e'),
                  subtitle: translate('text_63bab307a61c62af497e0599'),
                }
              : {
                  title: translate('text_62865498824cc10126ab2962'),
                  subtitle: translate('text_62865498824cc10126ab2968'),
                  buttonTitle: translate('text_62865498824cc10126ab296e'),
                  buttonVariant: 'primary',
                  buttonAction: () => location.reload(),
                },

            emptyState: getEmptyState(),
          }}
        />
      </InfiniteScroll>
    </>
  )
}

export default CouponsList
