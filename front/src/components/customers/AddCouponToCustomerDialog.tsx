import { gql, useApolloClient } from '@apollo/client'
import { useFormik } from 'formik'
import { forwardRef, RefObject, useMemo, useRef } from 'react'
import { number, object, string } from 'yup'

import { CouponCaption } from '~/components/coupons/CouponCaption'
import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { Chip } from '~/components/designSystem/Chip'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { Typography } from '~/components/designSystem/Typography'
import {
  AmountInputField,
  ComboBox,
  ComboBoxField,
  ComboboxItem,
  TextInputField,
} from '~/components/form'
import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import { deserializeAmount, serializeAmount } from '~/core/serializers/serializeAmount'
import {
  CouponBillableMetricsForCustomerFragment,
  CouponBillableMetricsForCustomerFragmentDoc,
  CouponCaptionFragmentDoc,
  CouponFrequency,
  CouponItemFragment,
  CouponPlansForCustomerFragment,
  CouponPlansForCustomerFragmentDoc,
  CouponStatusEnum,
  CouponTypeEnum,
  CreateAppliedCouponInput,
  CurrencyEnum,
  Customer,
  LagoApiError,
  useAddCouponMutation,
  useGetCouponForCustomerLazyQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment CouponPlansForCustomer on Plan {
    id
    name
  }

  fragment CouponBillableMetricsForCustomer on BillableMetric {
    id
    name
  }

  query getCouponForCustomer(
    $page: Int
    $limit: Int
    $status: CouponStatusEnum
    $searchTerm: String
  ) {
    coupons(page: $page, limit: $limit, status: $status, searchTerm: $searchTerm) {
      metadata {
        currentPage
        totalPages
      }
      collection {
        id
        name
        amountCurrency
        amountCents
        couponType
        percentageRate
        frequency
        frequencyDuration
        plans {
          ...CouponPlansForCustomer
        }
        billableMetrics {
          ...CouponBillableMetricsForCustomer
        }
        ...CouponCaption
      }
    }
  }

  mutation addCoupon($input: CreateAppliedCouponInput!) {
    createAppliedCoupon(input: $input) {
      id
    }
  }

  ${CouponBillableMetricsForCustomerFragmentDoc}
  ${CouponPlansForCustomerFragmentDoc}
  ${CouponCaptionFragmentDoc}
`

type FormType = CreateAppliedCouponInput & {
  couponType: CouponTypeEnum
  plans?: CouponPlansForCustomerFragment[] | null
  billableMetrics?: CouponBillableMetricsForCustomerFragment[] | null
}

export type AddCouponToCustomerDialogRef = DialogRef

interface AddCouponToCustomerDialogProps {
  customer?: Pick<Customer, 'id' | 'displayName'> | null
}

export const AddCouponToCustomerDialog = forwardRef<
  AddCouponToCustomerDialogRef,
  AddCouponToCustomerDialogProps
>(({ customer }: AddCouponToCustomerDialogProps, ref) => {
  const customerId = customer?.id
  const customerName = customer?.displayName
  const shouldRefetchOnClose = useRef(false)

  const { translate } = useInternationalization()
  const client = useApolloClient()
  const [getCoupons, { loading, data }] = useGetCouponForCustomerLazyQuery({
    variables: { limit: 50, status: CouponStatusEnum.Active },
    fetchPolicy: 'network-only',
    nextFetchPolicy: 'network-only',
    notifyOnNetworkStatusChange: true,
  })
  const [addCoupon] = useAddCouponMutation({
    context: {
      silentErrorCodes: [
        LagoApiError.CouponIsNotReusable,
        LagoApiError.UnprocessableEntity,
        LagoApiError.PlanOverlapping,
      ],
    },
    onCompleted({ createAppliedCoupon }) {
      if (createAppliedCoupon) {
        addToast({
          severity: 'success',
          translateKey: 'text_628b8c693e464200e00e49f2',
        })
      }
    },
  })
  const formikProps = useFormik<Omit<FormType, 'customerId'>>({
    initialValues: {
      couponId: '',
      amountCents: undefined,
      percentageRate: undefined,
      couponType: CouponTypeEnum.FixedAmount,
      frequency: undefined,
      frequencyDuration: undefined,
      amountCurrency: undefined,
      plans: undefined,
      billableMetrics: undefined,
    },
    validationSchema: object().shape({
      couponId: string().required(''),
      amountCents: number().when('couponType', {
        is: (couponType: CouponTypeEnum) =>
          !!couponType && couponType === CouponTypeEnum.FixedAmount,
        then: (schema) =>
          schema
            .typeError(translate('text_624ea7c29103fd010732ab7d'))
            .min(0.001, 'text_632d68358f1fedc68eed3e91')
            .required(''),
      }),
      amountCurrency: string()
        .when('couponType', {
          is: (couponType: CouponTypeEnum) =>
            !!couponType && couponType === CouponTypeEnum.FixedAmount,
          then: (schema) => schema.required(''),
        })
        .nullable(),
      percentageRate: number()
        .when('couponType', {
          is: (couponType: CouponTypeEnum) =>
            !!couponType && couponType === CouponTypeEnum.Percentage,
          then: (schema) =>
            schema
              .typeError(translate('text_624ea7c29103fd010732ab7d'))
              .min(0.001, 'text_633445d00315a713775f02a6')
              .required(''),
        })
        .nullable(),
      couponType: string().required('').nullable(),
      frequency: string().required('').nullable(),
      frequencyDuration: number()
        .when('frequency', {
          is: (frequency: CouponFrequency) =>
            !!frequency && frequency === CouponFrequency.Recurring,
          then: (schema) =>
            schema
              .typeError(translate('text_63314cfeb607e57577d894c9'))
              .min(1, 'text_63314cfeb607e57577d894c9')
              .required(''),
        })
        .nullable(),
    }),
    validateOnMount: true,
    enableReinitialize: true,
    onSubmit: async (
      { amountCents, amountCurrency, percentageRate, frequencyDuration, ...values },
      formikBag,
    ) => {
      if (!customerId) return

      const couponValues = {
        ...values,
        couponType: undefined,
        plans: undefined,
        billableMetrics: undefined,
      }

      const answer = await addCoupon({
        variables: {
          input: {
            customerId,
            amountCents:
              values.couponType === CouponTypeEnum.FixedAmount
                ? serializeAmount(amountCents || 0, amountCurrency || CurrencyEnum.Usd)
                : undefined,
            amountCurrency:
              values.couponType === CouponTypeEnum.FixedAmount ? amountCurrency : undefined,
            percentageRate:
              values.couponType === CouponTypeEnum.Percentage ? Number(percentageRate) : undefined,
            frequencyDuration:
              values.frequency === CouponFrequency.Recurring ? frequencyDuration : undefined,
            ...couponValues,
          },
        },
      })

      const { errors } = answer

      if (hasDefinedGQLError('CouponIsNotReusable', errors)) {
        formikBag.setFieldError(
          'couponId',
          translate('text_638f48274d41e3f1d01fc119', { customerFullName: customerName }),
        )
      } else if (hasDefinedGQLError('CurrenciesDoesNotMatch', errors, 'currency')) {
        formikBag.setFieldError('amountCurrency', '')
      } else if (hasDefinedGQLError('PlanOverlapping', errors)) {
        formikBag.setFieldError('couponId', '')
      } else {
        shouldRefetchOnClose.current = true
        ;(ref as unknown as RefObject<DialogRef>)?.current?.closeDialog()
      }
    },
  })

  const coupons = useMemo(() => {
    if (!data || !data?.coupons || !data?.coupons?.collection) return []

    return data?.coupons?.collection.map((coupon) => {
      const { id, name } = coupon

      return {
        label: name,
        labelNode: (
          <ComboboxItem>
            <Typography variant="body" color="grey700" noWrap>
              {name}
            </Typography>
            <CouponCaption coupon={coupon as CouponItemFragment} variant="caption" />
          </ComboboxItem>
        ),
        value: id,
      }
    })
  }, [data])

  return (
    <Dialog
      ref={ref}
      title={translate('text_628b8c693e464200e00e465b')}
      description={translate('text_628b8c693e464200e00e4669')}
      onOpen={() => {
        if (!loading && !data) {
          getCoupons()
        }
      }}
      onClose={() => {
        formikProps.resetForm()

        if (shouldRefetchOnClose.current) {
          shouldRefetchOnClose.current = false
          client.refetchQueries({
            include: ['getAppliedCouponsForCustomer', 'getAppliedCouponsForCouponDetails'],
          })
        }
      }}
      actions={({ closeDialog }) => (
        <>
          <Button variant="quaternary" onClick={closeDialog}>
            {translate('text_628b8c693e464200e00e4693')}
          </Button>
          <Button
            disabled={!formikProps.isValid}
            onClick={formikProps.submitForm}
            data-test="submit"
          >
            {translate('text_628b8c693e464200e00e46a1')}
          </Button>
        </>
      )}
    >
      <div className="mb-8 flex flex-col gap-6">
        <ComboBox
          name="selectCoupon"
          value={formikProps.values.couponId ? String(formikProps.values.couponId) : ''}
          label={translate('text_628b8c693e464200e00e4677')}
          data={coupons}
          loading={loading}
          searchQuery={getCoupons}
          placeholder={translate('text_628b8c693e464200e00e4685')}
          onChange={(value) => {
            const coupon = data?.coupons?.collection.find((c) => c.id === value)

            if (!!coupon) {
              formikProps.setValues({
                couponId: coupon.id,
                amountCents: deserializeAmount(
                  coupon.amountCents || 0,
                  coupon.amountCurrency || CurrencyEnum.Usd,
                ),
                amountCurrency: coupon.amountCurrency,
                percentageRate: coupon.percentageRate,
                couponType: coupon.couponType,
                frequency: coupon.frequency,
                frequencyDuration: coupon.frequencyDuration,
                plans: coupon.plans,
                billableMetrics: coupon.billableMetrics,
              })
            } else {
              formikProps.setFieldValue('couponId', undefined)
            }
          }}
          PopperProps={{ displayInDialog: true }}
        />

        {!!formikProps.values.plans?.length && (
          <div data-test="plan-limitation-section">
            <Typography className="mb-1" variant="captionHl" color="grey700">
              {translate('text_63d66aa2471035c8ff598857')}
            </Typography>
            <div className="flex flex-wrap gap-1">
              {formikProps.values.plans.map((plan) => (
                <Chip key={`coupon-plan-appied-to-${plan.id}`} label={plan.name} />
              ))}
            </div>
          </div>
        )}

        {!!formikProps.values.billableMetrics?.length && (
          <div data-test="billable-metric-limitation-section">
            <Typography className="mb-1" variant="captionHl" color="grey700">
              {translate('text_63d66aa2471035c8ff598857')}
            </Typography>
            <div className="flex flex-wrap gap-1">
              {formikProps.values.billableMetrics.map((bm) => (
                <Chip key={`coupon-billable-metric-appied-to-${bm.id}`} label={bm.name} />
              ))}
            </div>
          </div>
        )}

        {!!formikProps.values.couponId && (
          <>
            {formikProps.values.couponType === CouponTypeEnum.FixedAmount ? (
              <div className="flex gap-3">
                <AmountInputField
                  className="flex-1"
                  name="amountCents"
                  currency={formikProps.values.amountCurrency || CurrencyEnum.Usd}
                  beforeChangeFormatter={['positiveNumber']}
                  label={translate('text_628b8c693e464200e00e469b')}
                  formikProps={formikProps}
                />
                <ComboBoxField
                  containerClassName="max-w-30 mt-7"
                  name="amountCurrency"
                  data={Object.values(CurrencyEnum).map((currencyType) => ({
                    value: currencyType,
                  }))}
                  isEmptyNull={false}
                  disableClearable
                  formikProps={formikProps}
                  PopperProps={{ displayInDialog: true }}
                />
              </div>
            ) : (
              <TextInputField
                name="percentageRate"
                beforeChangeFormatter={['positiveNumber', 'quadDecimal']}
                label={translate('text_632d68358f1fedc68eed3e76')}
                placeholder={translate('text_632d68358f1fedc68eed3e86')}
                formikProps={formikProps}
                InputProps={{
                  endAdornment: (
                    <Typography className="mr-4 shrink-0" variant="body" color="textSecondary">
                      {translate('text_632d68358f1fedc68eed3e93')}
                    </Typography>
                  ),
                }}
              />
            )}

            <ComboBoxField
              name="frequency"
              label={translate('text_632d68358f1fedc68eed3e9d')}
              helperText={translate('text_632d68358f1fedc68eed3eab')}
              data={[
                {
                  value: CouponFrequency.Once,
                  label: translate('text_632d68358f1fedc68eed3ea3'),
                },
                {
                  value: CouponFrequency.Recurring,
                  label: translate('text_632d68358f1fedc68eed3e64'),
                },
                {
                  value: CouponFrequency.Forever,
                  label: translate('text_63c83a3476e46bc6ab9d85d6'),
                },
              ]}
              disableClearable
              formikProps={formikProps}
              PopperProps={{ displayInDialog: true }}
            />

            {formikProps.values.frequency === CouponFrequency.Recurring && (
              <TextInputField
                name="frequencyDuration"
                beforeChangeFormatter={['positiveNumber', 'int']}
                label={translate('text_632d68358f1fedc68eed3e80')}
                placeholder={translate('text_632d68358f1fedc68eed3e88')}
                formikProps={formikProps}
                InputProps={{
                  endAdornment: (
                    <Typography className="mr-4 shrink-0" variant="body" color="textSecondary">
                      {translate('text_632d68358f1fedc68eed3e95')}
                    </Typography>
                  ),
                }}
              />
            )}
          </>
        )}
        {!!formikProps.errors?.couponId && formikProps.errors.couponId !== '' && (
          <Alert type="danger">{formikProps.errors?.couponId}</Alert>
        )}
        {!!formikProps.values.amountCurrency &&
          !!Object.keys(formikProps.errors).includes('amountCurrency') && (
            <Alert type="danger">{translate('text_632c88c97af78294bc02ea9d')}</Alert>
          )}
        {!!formikProps.values.couponId && formikProps.errors.couponId === '' && (
          <Alert type="danger">{translate('text_64352657267c3d916f96278a')}</Alert>
        )}
      </div>
    </Dialog>
  )
})

AddCouponToCustomerDialog.displayName = 'AddCouponToCustomerDialog'
