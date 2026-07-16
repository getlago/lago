import { gql } from '@apollo/client'
import { tw } from 'lago-design-system'
import { useRef } from 'react'
import { generatePath } from 'react-router-dom'

import { CouponCaption } from '~/components/coupons/CouponCaption'
import { APPLIED_COUPON_STATUS_CONFIG } from '~/components/coupons/utils'
import {
  AddCouponToCustomerDialog,
  AddCouponToCustomerDialogRef,
} from '~/components/customers/AddCouponToCustomerDialog'
import { Button } from '~/components/designSystem/Button'
import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { Status } from '~/components/designSystem/Status'
import { Table, TableColumn } from '~/components/designSystem/Table/Table'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { PageSectionTitle } from '~/components/layouts/Section'
import { CouponDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { COUPON_DETAILS_ROUTE } from '~/core/router'
import {
  AppliedCouponCaptionFragmentDoc,
  AppliedCouponStatusEnum,
  useGetAppliedCouponsForCustomerQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { usePermissions } from '~/hooks/usePermissions'
import { useTerminateAppliedCoupon } from '~/hooks/useTerminateAppliedCoupon'

gql`
  query getAppliedCouponsForCustomer($page: Int, $limit: Int, $externalCustomerId: String) {
    appliedCoupons(page: $page, limit: $limit, externalCustomerId: $externalCustomerId) {
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
      }
    }
  }

  ${AppliedCouponCaptionFragmentDoc}
`

interface CustomerAppliedCouponsListProps {
  customerId: string
  customerExternalId: string
  customerDisplayName: string
}

export const CustomerAppliedCouponsList = ({
  customerId,
  customerExternalId,
  customerDisplayName,
}: CustomerAppliedCouponsListProps) => {
  const { translate } = useInternationalization()
  const { hasPermissions } = usePermissions()
  const { terminateCoupon } = useTerminateAppliedCoupon()
  const centralizedDialog = useCentralizedDialog()
  const addCouponDialogRef = useRef<AddCouponToCustomerDialogRef>(null)

  const { data, error, loading, fetchMore } = useGetAppliedCouponsForCustomerQuery({
    variables: { externalCustomerId: customerExternalId, page: 0, limit: 20 },
    skip: !customerExternalId,
    notifyOnNetworkStatusChange: true,
  })

  const appliedCoupons = data?.appliedCoupons?.collection || []

  const columns: Array<TableColumn<(typeof appliedCoupons)[number]>> = [
    {
      key: 'status',
      title: translate('text_1772536695408q802eishgnx'),
      minWidth: 90,
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
      key: 'coupon.name',
      title: translate('text_6419c64eace749372fc72b0f'),
      maxSpace: true,
      minWidth: 160,
      maxWidth: 600,
      content: ({ coupon: { name, code } }) => (
        <div className="flex flex-col">
          <Typography variant="body" color="grey700" className="text-nowrap">
            {name}
          </Typography>
          {code ? (
            <TypographyWithCopy compact noWrap variant="body">
              {code}
            </TypographyWithCopy>
          ) : null}
        </div>
      ),
    },
    {
      key: 'amountCurrency',
      textAlign: 'right',
      title: translate('text_632d68358f1fedc68eed3e9d'),
      content: (appliedCoupon) => (
        <CouponCaption
          variant="subhead2"
          className={tw('text-nowrap text-grey-600', {
            'pr-1': !!actionColumn,
          })}
          coupon={appliedCoupon}
        />
      ),
    },
  ]

  const getRowActionLink = (appliedCoupon: (typeof appliedCoupons)[number]) =>
    generatePath(COUPON_DETAILS_ROUTE, {
      couponId: appliedCoupon.coupon.id,
      tab: CouponDetailsTabsOptionsEnum.overview,
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

  const sectionAction = hasPermissions(['couponsAttach'])
    ? {
        title: translate('text_628b8dc14c71840130f8d8a1'),
        onClick: () => {
          addCouponDialogRef.current?.openDialog()
        },
      }
    : undefined

  const fetchNextPage = () => {
    const { currentPage = 0, totalPages = 0 } = data?.appliedCoupons?.metadata || {}

    currentPage < totalPages &&
      !loading &&
      fetchMore({
        variables: { page: currentPage + 1 },
      })
  }

  return (
    <>
      <PageSectionTitle
        title={translate('text_62865498824cc10126ab2956')}
        subtitle={translate('text_1736950586920yq3xq4gols8')}
        action={sectionAction}
      />

      <InfiniteScroll onBottom={fetchNextPage}>
        <Table
          name="customer-coupons-list"
          data={appliedCoupons}
          isLoading={loading}
          hasError={!!error}
          containerSize={0}
          rowSize={72}
          placeholder={{
            emptyState: {
              title: translate('text_1774469243856d8omf8kuryj'),
              subtitle: translate('text_17744692844137gqe9ung3gl'),
            },
          }}
          onRowActionLink={getRowActionLink}
          columns={columns}
          actionColumn={actionColumn}
        />
      </InfiniteScroll>

      <AddCouponToCustomerDialog
        ref={addCouponDialogRef}
        customer={{ id: customerId, displayName: customerDisplayName }}
      />
    </>
  )
}
