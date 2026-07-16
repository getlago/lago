import { gql } from '@apollo/client'
import { revalidateLogic } from '@tanstack/react-form'
import { useCallback, useRef, useState } from 'react'
import { z } from 'zod'

import { Button } from '~/components/designSystem/Button'
import type {
  EntityData,
  OnDiscountCommand,
} from '~/components/designSystem/RichTextEditor/common/RichTextEditorContext'
import type { DiscountBlockAttributes } from '~/components/designSystem/RichTextEditor/extensions/DiscountBlock.schema'
import { Typography } from '~/components/designSystem/Typography'
import { useDrawer } from '~/components/drawers/useDrawer'
import { ComboBox } from '~/components/form/ComboBox/ComboBox'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import type { BillingItemsPayload } from '~/core/serializers/serializeQuoteBillingItems'
import {
  type CouponPayload,
  type DiscountFormItem,
  fromCoupons,
  toCoupons,
} from '~/core/serializers/serializeQuoteCoupons'
import {
  CouponFrequency,
  CouponStatusEnum,
  CouponTypeEnum,
  CurrencyEnum,
  useGetCouponsForDiscountDrawerLazyQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm, withForm } from '~/hooks/forms/useAppform'

gql`
  query getCouponsForDiscountDrawer(
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
        code
        couponType
        amountCents
        percentageRate
        frequency
        frequencyDuration
      }
    }
  }
`

export const DISCOUNT_DRAWER_SAVE_TEST_ID = 'discount-drawer-save'

interface DiscountFormValues {
  couponId: string
  couponType: CouponTypeEnum
  name: string
  code: string
  currency: CurrencyEnum
  amount: string
  // Kept as strings — the TanStack TextInputField stores raw string values,
  // EXCEPT frequencyDuration: the `int` beforeChangeFormatter runs parseInt and
  // stores a number, so its value can be a string (prefill/default) or a number
  // (after the user types). Coerced to number|null when building the payload.
  percentageRate: string
  frequency: CouponFrequency
  frequencyDuration: string | number
}

const makeDefaults = (currency: CurrencyEnum): DiscountFormValues => ({
  couponId: '',
  couponType: CouponTypeEnum.FixedAmount,
  name: '',
  code: '',
  currency,
  amount: '',
  percentageRate: '',
  frequency: CouponFrequency.Forever,
  frequencyDuration: '',
})

const schema = z
  .object({
    couponId: z.string().min(1),
    couponType: z.nativeEnum(CouponTypeEnum),
    name: z.string(),
    code: z.string(),
    currency: z.nativeEnum(CurrencyEnum),
    amount: z.string(),
    percentageRate: z.string(),
    frequency: z.nativeEnum(CouponFrequency),
    // number when set via the `int` input formatter, string on prefill/default
    frequencyDuration: z.union([z.string(), z.number()]),
  })
  .superRefine((data, ctx) => {
    if (data.couponType === CouponTypeEnum.FixedAmount && !data.amount) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'text_624ea7c29103fd010732ab7d',
        path: ['amount'],
      })
    }

    if (data.couponType === CouponTypeEnum.Percentage && !data.percentageRate) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'text_624ea7c29103fd010732ab7d',
        path: ['percentageRate'],
      })
    }

    if (data.frequency === CouponFrequency.Recurring && !data.frequencyDuration) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'text_63314cfeb607e57577d894c9',
        path: ['frequencyDuration'],
      })
    }
  })

const DiscountDrawerContent = withForm({
  defaultValues: makeDefaults(CurrencyEnum.Usd),
  props: { lockedCurrency: CurrencyEnum.Usd as CurrencyEnum },
  render: function Render({ form, lockedCurrency }) {
    const { translate } = useInternationalization()
    const [getCoupons, { loading, data }] = useGetCouponsForDiscountDrawerLazyQuery({
      variables: { limit: 50, status: CouponStatusEnum.Active },
      fetchPolicy: 'network-only',
      notifyOnNetworkStatusChange: true,
    })

    const coupons = (data?.coupons?.collection ?? []).map((c) => ({
      value: c.id,
      label: c.name,
    }))

    return (
      <div className="flex flex-col gap-6">
        <CenteredPage.PageTitle
          title={translate('text_1782891666475u5j60v91cv2')}
          description={translate('text_1782891666475ht76172d37q')}
        />

        <form.Subscribe
          selector={(s) => [s.values.couponId, s.values.couponType, s.values.frequency] as const}
        >
          {([couponId, couponType, frequency]) => (
            <>
              <ComboBox
                name="selectCoupon"
                value={couponId ? String(couponId) : ''}
                label={translate('text_628b8c693e464200e00e4677')}
                placeholder={translate('text_628b8c693e464200e00e4685')}
                data={coupons}
                loading={loading}
                searchQuery={getCoupons}
                onChange={(value) => {
                  const coupon = data?.coupons?.collection.find((c) => c.id === value)

                  if (!coupon) {
                    form.setFieldValue('couponId', '')
                    return
                  }

                  form.setFieldValue('couponId', coupon.id)
                  form.setFieldValue('couponType', coupon.couponType)
                  form.setFieldValue('name', coupon.name)
                  form.setFieldValue('code', coupon.code ?? '')
                  form.setFieldValue(
                    'amount',
                    deserializeAmount(coupon.amountCents ?? 0, lockedCurrency).toString(),
                  )
                  form.setFieldValue('currency', lockedCurrency)
                  form.setFieldValue(
                    'percentageRate',
                    coupon.percentageRate !== null && coupon.percentageRate !== undefined
                      ? String(coupon.percentageRate)
                      : '',
                  )
                  form.setFieldValue('frequency', coupon.frequency)
                  form.setFieldValue(
                    'frequencyDuration',
                    coupon.frequencyDuration !== null && coupon.frequencyDuration !== undefined
                      ? String(coupon.frequencyDuration)
                      : '',
                  )
                }}
              />

              {!!couponId && couponType === CouponTypeEnum.FixedAmount && (
                <div className="flex gap-3">
                  <form.AppField name="amount">
                    {(field) => (
                      <field.AmountInputField
                        className="flex-1"
                        currency={lockedCurrency}
                        beforeChangeFormatter={['positiveNumber']}
                        label={translate('text_628b8c693e464200e00e469b')}
                      />
                    )}
                  </form.AppField>
                  <form.AppField name="currency">
                    {(field) => (
                      <field.ComboBoxField
                        className="mt-7 max-w-30"
                        data={[{ value: lockedCurrency }]}
                        disabled
                        disableClearable
                      />
                    )}
                  </form.AppField>
                </div>
              )}

              {!!couponId && couponType === CouponTypeEnum.Percentage && (
                <form.AppField name="percentageRate">
                  {(field) => (
                    <field.TextInputField
                      beforeChangeFormatter={['positiveNumber', 'quadDecimal']}
                      label={translate('text_632d68358f1fedc68eed3e76')}
                      placeholder={translate('text_632d68358f1fedc68eed3e86')}
                      InputProps={{
                        endAdornment: (
                          <Typography
                            className="mr-4 shrink-0"
                            variant="body"
                            color="textSecondary"
                          >
                            {translate('text_632d68358f1fedc68eed3e93')}
                          </Typography>
                        ),
                      }}
                    />
                  )}
                </form.AppField>
              )}

              {!!couponId && (
                <form.AppField name="frequency">
                  {(field) => (
                    <field.ComboBoxField
                      label={translate('text_632d68358f1fedc68eed3e9d')}
                      helperText={translate('text_632d68358f1fedc68eed3eab')}
                      disableClearable
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
                    />
                  )}
                </form.AppField>
              )}

              {!!couponId && frequency === CouponFrequency.Recurring && (
                <form.AppField name="frequencyDuration">
                  {(field) => (
                    <field.TextInputField
                      beforeChangeFormatter={['positiveNumber', 'int']}
                      label={translate('text_632d68358f1fedc68eed3e80')}
                      placeholder={translate('text_632d68358f1fedc68eed3e88')}
                      InputProps={{
                        endAdornment: (
                          <Typography
                            className="mr-4 shrink-0"
                            variant="body"
                            color="textSecondary"
                          >
                            {translate('text_632d68358f1fedc68eed3e95')}
                          </Typography>
                        ),
                      }}
                    />
                  )}
                </form.AppField>
              )}
            </>
          )}
        </form.Subscribe>
      </div>
    )
  },
})

interface PendingSave {
  onSave: (attrs: DiscountBlockAttributes) => void
  localId: string
}

export const useDiscountDrawer = (
  billingItems: BillingItemsPayload | null | undefined,
  options: { currency: CurrencyEnum; onPersist?: (billingItems: BillingItemsPayload) => void },
): {
  onDiscountCommand: OnDiscountCommand
  entities: Record<string, EntityData>
  syncDiscountBlocks: (blocks: DiscountBlockAttributes[]) => BillingItemsPayload | undefined
} => {
  const { translate } = useInternationalization()
  const drawer = useDrawer()
  const currency = options.currency
  const { onPersist } = options

  const initial = fromCoupons(billingItems?.coupons ?? [])

  const itemsRef = useRef<Record<string, DiscountFormItem>>(
    Object.fromEntries(initial.discountItems.map((i) => [i.localId, i])),
  )
  const originalPayloadsRef = useRef<Record<string, CouponPayload>>(initial.originalPayloads)
  const [entities, setEntities] = useState<Record<string, EntityData>>(initial.entities)
  const entitiesRef = useRef<Record<string, EntityData>>(initial.entities)

  // Ref bridge: a single stable onSubmit reads the pending save target set right
  // before drawer.open, instead of mutating form.options.onSubmit per open.
  const pendingSaveRef = useRef<PendingSave | null>(null)

  const rebuild = useCallback((): BillingItemsPayload => {
    const items = Object.values(itemsRef.current)
    const coupons = toCoupons(items, originalPayloadsRef.current)
    const { entities: nextEntities } = fromCoupons(coupons)

    entitiesRef.current = nextEntities
    setEntities(nextEntities)

    return { ...billingItems, coupons }
  }, [billingItems])

  const form = useAppForm({
    defaultValues: makeDefaults(currency),
    validationLogic: revalidateLogic(),
    validators: { onDynamic: schema },
    onSubmit: async ({ value }) => {
      const pending = pendingSaveRef.current

      if (!pending) return

      const { onSave, localId } = pending

      itemsRef.current[localId] = {
        localId,
        couponId: value.couponId,
        couponType: value.couponType,
        name: value.name,
        code: value.code,
        currency,
        amount: value.amount,
        percentageRate: value.percentageRate ? Number(value.percentageRate) : null,
        frequency: value.frequency,
        frequencyDuration: value.frequencyDuration ? Number(value.frequencyDuration) : null,
      }

      // Ensure a fresh payload snapshot for newly added coupons AND when the user
      // switches an existing line to a different coupon. Without the id check, an
      // edit that changes the coupon keeps the previous snapshot, so toCoupons
      // rebuilds the line from the old coupon's identity (name/code/type) and both
      // the editor block and the preview keep showing the old coupon.
      const existingSnapshot = originalPayloadsRef.current[localId]

      if (!existingSnapshot || existingSnapshot.id !== value.couponId) {
        originalPayloadsRef.current[localId] = {
          position: existingSnapshot?.position ?? Object.keys(itemsRef.current).length,
          code: value.code,
          id: value.couponId,
          name: value.name,
          type: value.couponType === CouponTypeEnum.Percentage ? 'percentage' : 'fixed_amount',
          amount_cents: null,
          percentage_rate: null,
          currency,
          frequency: 'forever',
          frequency_duration: null,
          expiration_at: null,
          limited_plans: false,
          plan_codes: [],
          limited_billable_metrics: false,
          billable_metric_codes: [],
          coupon_overrides: null,
          catalog_snapshot: null,
          resolved_payload: null,
        }
      }

      const updated = rebuild()

      onSave({ couponId: value.couponId, localId })
      onPersist?.(updated)
      drawer.close()
    },
  })

  const handleFormSubmit = (event?: React.FormEvent) => {
    event?.preventDefault()
    form.handleSubmit()
  }

  const onDiscountCommand = useCallback<OnDiscountCommand>(
    ({ onSave, editData }) => {
      const localId = editData?.localId ?? crypto.randomUUID()
      const existing = editData ? itemsRef.current[localId] : undefined

      pendingSaveRef.current = { onSave, localId }

      form.reset(
        existing
          ? {
              couponId: existing.couponId,
              couponType: existing.couponType,
              name: existing.name,
              code: existing.code,
              currency,
              amount: existing.amount,
              percentageRate:
                existing.percentageRate !== null && existing.percentageRate !== undefined
                  ? String(existing.percentageRate)
                  : '',
              frequency: existing.frequency,
              frequencyDuration:
                existing.frequencyDuration !== null && existing.frequencyDuration !== undefined
                  ? String(existing.frequencyDuration)
                  : '',
            }
          : makeDefaults(currency),
        { keepDefaultValues: true },
      )

      drawer.open({
        title: translate('text_1782891666475j9e81afl8in'),
        children: (
          <form onSubmit={handleFormSubmit}>
            <button type="submit" hidden tabIndex={-1} />
            <DiscountDrawerContent form={form} lockedCurrency={currency} />
          </form>
        ),
        actions: (
          <div className="flex items-center justify-end gap-3">
            <Button variant="quaternary" onClick={() => drawer.close()}>
              {translate('text_6411e6b530cb47007488b027')}
            </Button>
            <form.Subscribe selector={({ canSubmit }) => canSubmit}>
              {(canSubmit) => (
                <Button
                  data-test={DISCOUNT_DRAWER_SAVE_TEST_ID}
                  onClick={() => handleFormSubmit()}
                  disabled={!canSubmit}
                >
                  {translate('text_17295436903260tlyb1gp1i7')}
                </Button>
              )}
            </form.Subscribe>
          </div>
        ),
      })
    },
    // form and handleFormSubmit are stable (closure over form) — safe to omit
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [drawer, form, translate, currency],
  )

  const syncDiscountBlocks = useCallback(
    (blocks: DiscountBlockAttributes[]): BillingItemsPayload | undefined => {
      const present = new Set(blocks.map((b) => b.localId))
      let changed = false

      for (const key of Object.keys(itemsRef.current)) {
        if (!present.has(key)) {
          delete itemsRef.current[key]
          delete originalPayloadsRef.current[key]
          changed = true
        }
      }

      if (!changed) return undefined

      return rebuild()
    },
    [rebuild],
  )

  return { onDiscountCommand, entities, syncDiscountBlocks }
}
