import { CodeSnippet } from '~/components/CodeSnippet'
import { envGlobalVar } from '~/core/apolloClient'
import { serializeAmount } from '~/core/serializers/serializeAmount'
import { snippetBuilder, SnippetVariables } from '~/core/utils/snippetBuilder'
import {
  BillableMetricsForCouponsFragment,
  CouponExpiration,
  CouponFrequency,
  CouponTypeEnum,
  CreateCouponInput,
  CurrencyEnum,
  PlansForCouponsFragment,
} from '~/generated/graphql'

const { apiUrl } = envGlobalVar()

const getSnippets = (
  hasPlanLimit: boolean,
  hasBillableMetricLimit: boolean,
  limitPlansList?: PlansForCouponsFragment[],
  limitBillableMetricsList?: BillableMetricsForCouponsFragment[],
  coupon?: CreateCouponInput,
) => {
  if (!coupon || !coupon.code) return '# Fill the form to generate the code snippet'
  const {
    amountCents,
    amountCurrency,
    code,
    couponType,
    expiration,
    expirationAt,
    frequency,
    frequencyDuration,
    percentageRate,
  } = coupon

  return snippetBuilder({
    title: 'Assign a coupon to a customer',
    method: 'POST',
    url: `${apiUrl}/api/v1/applied_coupons`,
    headers: [
      { Authorization: `Bearer $${SnippetVariables.API_KEY}` },
      { 'Content-Type': 'application/json' },
    ],
    data: {
      applied_coupon: {
        external_customer_id: SnippetVariables.EXTERNAL_CUSTOMER_ID,
        coupon_code: code,
        coupon_type: couponType,
        ...(couponType === CouponTypeEnum.FixedAmount
          ? {
              amount_cents: serializeAmount(amountCents || 0, amountCurrency || CurrencyEnum.Usd),
              amount_currency: amountCurrency,
            }
          : {
              percentage_rate: percentageRate ? percentageRate : SnippetVariables.MUST_BE_DEFINED,
            }),
        frequency: frequency,
        ...(frequency === CouponFrequency.Recurring && {
          frequency_duration: frequencyDuration
            ? frequencyDuration
            : SnippetVariables.MUST_BE_DEFINED,
        }),
        expiration: expiration,
        ...(expiration === CouponExpiration.TimeLimit && {
          expiration_date: expirationAt ? expirationAt : SnippetVariables.MUST_BE_DEFINED,
        }),
        ...(hasPlanLimit &&
          !!limitPlansList?.length && {
            applies_to: { plan_codes: limitPlansList.map((p) => p.code) },
          }),
        ...(hasBillableMetricLimit &&
          !!limitBillableMetricsList?.length && {
            applies_to: { billable_metrics_codes: limitBillableMetricsList.map((b) => b.code) },
          }),
      },
    },
    footerComment: `To use the snippet, don’t forget to edit your ${SnippetVariables.API_KEY} and ${SnippetVariables.EXTERNAL_CUSTOMER_ID}`,
  })
}

interface CouponCodeSnippetProps {
  loading?: boolean
  coupon?: CreateCouponInput
  limitPlansList?: PlansForCouponsFragment[]
  limitBillableMetricsList?: BillableMetricsForCouponsFragment[]
  hasPlanLimit: boolean
  hasBillableMetricLimit: boolean
}

export const CouponCodeSnippet = ({
  coupon,
  loading,
  hasPlanLimit,
  limitPlansList,
  hasBillableMetricLimit,
  limitBillableMetricsList,
}: CouponCodeSnippetProps) => {
  return (
    <CodeSnippet
      loading={loading}
      language="bash"
      code={getSnippets(
        hasPlanLimit,
        hasBillableMetricLimit,
        limitPlansList,
        limitBillableMetricsList,
        coupon,
      )}
    />
  )
}
