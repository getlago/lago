import { gql } from '@apollo/client'
import { useEffect, useMemo } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import { FORM_ERRORS_ENUM } from '~/core/constants/form'
import { CouponDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { COUPON_DETAILS_ROUTE, ERROR_404_ROUTE, useNavigate } from '~/core/router'
import { serializeAmount } from '~/core/serializers/serializeAmount'
import {
  BillableMetricsForCouponsFragment,
  BillableMetricsForCouponsFragmentDoc,
  CouponExpiration,
  CouponFrequency,
  CouponItemFragmentDoc,
  CouponTypeEnum,
  CreateCouponInput,
  CurrencyEnum,
  EditCouponFragment,
  LagoApiError,
  PlansForCouponsFragment,
  PlansForCouponsFragmentDoc,
  UpdateCouponInput,
  useCreateCouponMutation,
  useGetSingleCouponQuery,
  useUpdateCouponMutation,
} from '~/generated/graphql'

gql`
  fragment EditCoupon on Coupon {
    id
    amountCents
    amountCurrency
    appliedCouponsCount
    code
    couponType
    description
    expiration
    expirationAt
    frequency
    frequencyDuration
    limitedBillableMetrics
    limitedPlans
    name
    percentageRate
    reusable
    plans {
      ...PlansForCoupons
    }
    billableMetrics {
      ...BillableMetricsForCoupons
    }
  }

  query getSingleCoupon($id: ID!) {
    coupon(id: $id) {
      ...EditCoupon
    }
  }

  mutation createCoupon($input: CreateCouponInput!) {
    createCoupon(input: $input) {
      id
    }
  }

  mutation updateCoupon($input: UpdateCouponInput!) {
    updateCoupon(input: $input) {
      ...CouponItem
    }
  }

  ${CouponItemFragmentDoc}
  ${PlansForCouponsFragmentDoc}
  ${BillableMetricsForCouponsFragmentDoc}
`

type CouponFormInput = CreateCouponInput &
  UpdateCouponInput & {
    hasPlanLimit?: boolean
    limitPlansList?: PlansForCouponsFragment[]
    hasBillableMetricLimit?: boolean
    limitBillableMetricsList?: BillableMetricsForCouponsFragment[]
  }

type UseCreateEditCouponReturn = {
  loading: boolean
  isEdition: boolean
  coupon?: EditCouponFragment
  errorCode?: string
  onSave: (value: CouponFormInput) => Promise<void>
}

const formatCouponInput = (values: CouponFormInput) => {
  const {
    amountCents,
    amountCurrency,
    expirationAt,
    percentageRate,
    frequencyDuration,
    hasPlanLimit,
    limitPlansList,
    hasBillableMetricLimit,
    limitBillableMetricsList,
    ...others
  } = values

  return {
    amountCents:
      values.couponType === CouponTypeEnum.FixedAmount
        ? serializeAmount(Number(amountCents), amountCurrency || CurrencyEnum.Usd)
        : undefined,
    amountCurrency: values.couponType === CouponTypeEnum.FixedAmount ? amountCurrency : undefined,
    percentageRate:
      values.couponType === CouponTypeEnum.Percentage ? Number(percentageRate) : undefined,
    expirationAt:
      values.expiration === CouponExpiration.NoExpiration && expirationAt ? null : expirationAt,
    frequencyDuration:
      values.frequency === CouponFrequency.Recurring ? frequencyDuration : undefined,
    appliesTo: {
      planIds: hasPlanLimit && limitPlansList?.length ? limitPlansList.map((p) => p.id) : [],
      billableMetricIds:
        hasBillableMetricLimit && limitBillableMetricsList?.length
          ? limitBillableMetricsList.map((b) => b.id)
          : [],
    },
    ...others,
  }
}

export const useCreateEditCoupon: () => UseCreateEditCouponReturn = () => {
  const navigate = useNavigate()
  const { couponId } = useParams()
  const { data, loading, error } = useGetSingleCouponQuery({
    context: { silentError: LagoApiError.NotFound },
    variables: { id: couponId as string },
    skip: !couponId,
  })
  const [create, { error: createError }] = useCreateCouponMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    onCompleted({ createCoupon }) {
      if (!!createCoupon) {
        addToast({
          severity: 'success',
          translateKey: 'text_633336532bdf72cb62dc0690',
        })
        navigate(
          generatePath(COUPON_DETAILS_ROUTE, {
            couponId: createCoupon.id,
            tab: CouponDetailsTabsOptionsEnum.overview,
          }),
        )
      }
    },
  })
  const [update, { error: updateError }] = useUpdateCouponMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    onCompleted({ updateCoupon }) {
      if (!!updateCoupon) {
        addToast({
          severity: 'success',
          translateKey: 'text_6287a9bdac160c00b2e0fc81',
        })
        navigate(
          generatePath(COUPON_DETAILS_ROUTE, {
            couponId: updateCoupon.id,
            tab: CouponDetailsTabsOptionsEnum.overview,
          }),
        )
      }
    },
  })

  useEffect(() => {
    if (hasDefinedGQLError('NotFound', error, 'coupon')) {
      navigate(ERROR_404_ROUTE)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [error])

  const errorCode = useMemo(() => {
    if (hasDefinedGQLError('ValueAlreadyExist', createError || updateError)) {
      return FORM_ERRORS_ENUM.existingCode
    }

    return undefined
  }, [createError, updateError])

  return useMemo(
    () => ({
      loading,
      isEdition: !!couponId,
      errorCode,
      coupon: !data?.coupon ? undefined : data?.coupon,
      onSave: !!couponId
        ? async (values) => {
            await update({
              variables: {
                input: {
                  ...formatCouponInput(values),
                  id: couponId,
                },
              },
            })
          }
        : async (values) => {
            await create({
              variables: {
                input: formatCouponInput(values),
              },
            })
          },
    }),
    [loading, couponId, errorCode, data?.coupon, update, create],
  )
}
