import InputAdornment from '@mui/material/InputAdornment'
import { revalidateLogic, useStore } from '@tanstack/react-form'
import { Icon } from 'lago-design-system'
import { useEffect, useState } from 'react'
import { generatePath } from 'react-router-dom'

import { CouponCodeSnippet } from '~/components/coupons/CouponCodeSnippet'
import { Alert } from '~/components/designSystem/Alert'
import { Avatar } from '~/components/designSystem/Avatar'
import { Button } from '~/components/designSystem/Button'
import { Card } from '~/components/designSystem/Card'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { Checkbox, DatePicker } from '~/components/form'
import NameAndCodeGroup from '~/components/form/NameAndCodeGroup/NameAndCodeGroup'
import { FORM_ERRORS_ENUM } from '~/core/constants/form'
import { CouponDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { COUPON_DETAILS_ROUTE, COUPONS_ROUTE, useNavigate } from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { endOfDayIso } from '~/core/utils/dateUtils'
import { scrollToTop } from '~/core/utils/domUtils'
import {
  BillableMetricsForCouponsFragment,
  CouponExpiration,
  CouponFrequency,
  CouponTypeEnum,
  CreateCouponInput,
  CurrencyEnum,
  PlansForCouponsFragment,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'
import { useCreateEditCoupon } from '~/hooks/useCreateEditCoupon'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { useAddBillableMetricToCouponDialog } from '~/pages/createCoupon/dialogs/AddBillableMetricToCouponDialog'
import { useAddPlanToCouponDialog } from '~/pages/createCoupon/dialogs/AddPlanToCouponDialog'
import { PageHeader } from '~/styles'
import { FormLoadingSkeleton, Main, Side, Subtitle, Title } from '~/styles/mainObjectsForm'

import { CouponFormValues, couponValidationSchema } from './createCoupon/validationSchema'

export const COUPONS_FORM_ID = 'coupon-form'

// Test ID constants
export const COUPON_DESCRIPTION_INPUT_TEST_ID = 'coupon-description-input'
export const COUPON_AMOUNT_INPUT_TEST_ID = 'coupon-amount-input'
export const COUPON_PERCENTAGE_INPUT_TEST_ID = 'coupon-percentage-input'
export const COUPON_CODE_SNIPPET_TEST_ID = 'coupon-code-snippet'
export const COUPON_EXPIRATION_SECTION_TEST_ID = 'coupon-expiration-section'
export const COUPON_LIMIT_ERROR_TEST_ID = 'coupon-limit-error'

const CreateCoupon = () => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const { organization } = useOrganizationInfos()
  const { isEdition, loading, coupon, errorCode, onSave } = useCreateEditCoupon()
  const warningDialog = useCentralizedDialog()
  const { openAddPlanToCouponDialog } = useAddPlanToCouponDialog()
  const { openAddBillableMetricToCouponDialog } = useAddBillableMetricToCouponDialog()

  const defaultValues: CouponFormValues = {
    amountCents: coupon?.amountCents
      ? String(deserializeAmount(coupon?.amountCents, coupon?.amountCurrency || CurrencyEnum.Usd))
      : coupon?.amountCents || undefined,
    amountCurrency: coupon?.amountCurrency || organization?.defaultCurrency || CurrencyEnum.Usd,
    code: coupon?.code || '',
    couponType: coupon?.couponType || CouponTypeEnum.FixedAmount,
    description: coupon?.description || '',
    expiration: coupon?.expiration || CouponExpiration.NoExpiration,
    expirationAt: coupon?.expirationAt || undefined,
    frequency: coupon?.frequency || CouponFrequency.Once,
    frequencyDuration: coupon?.frequencyDuration || undefined,
    name: coupon?.name || '',
    percentageRate: coupon?.percentageRate || undefined,
    reusable: coupon?.reusable === undefined ? true : coupon.reusable,
    hasPlanLimit: (coupon?.plans?.length ?? 0) > 0,
    limitPlansList: coupon?.plans || [],
    hasBillableMetricLimit: (coupon?.billableMetrics?.length ?? 0) > 0,
    limitBillableMetricsList: coupon?.billableMetrics || [],
  }

  const form = useAppForm({
    defaultValues,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: couponValidationSchema,
    },
    onSubmit: async ({ value }) => {
      await onSave(value as unknown as Parameters<typeof onSave>[0])
    },
  })

  const [shouldDisplayDescription, setShouldDisplayDescription] = useState<boolean>(
    !!coupon?.description,
  )

  // Subscribe to form values for conditional rendering
  const couponType = useStore(form.store, (state) => state.values.couponType)
  const frequency = useStore(form.store, (state) => state.values.frequency)
  const expiration = useStore(form.store, (state) => state.values.expiration)
  const reusable = useStore(form.store, (state) => state.values.reusable)
  const amountCurrency = useStore(form.store, (state) => state.values.amountCurrency)
  const expirationAt = useStore(form.store, (state) => state.values.expirationAt)
  const formHasPlanLimit = useStore(form.store, (state) => state.values.hasPlanLimit)
  const formHasBillableMetricLimit = useStore(
    form.store,
    (state) => state.values.hasBillableMetricLimit,
  )
  const limitPlansList = useStore(form.store, (state) => state.values.limitPlansList)
  const limitBillableMetricsList = useStore(
    form.store,
    (state) => state.values.limitBillableMetricsList,
  )

  const codeValue = useStore(form.store, (state) => state.values.code)

  // Subscribe to form state
  const isDirty = useStore(form.store, (state) => state.isDirty)
  const submissionAttempts = useStore(form.store, (state) => state.submissionAttempts)

  // Get all form values for the code snippet
  const formValues = useStore(form.store, (state) => state.values)

  const attachPlanToCoupon = (plan: PlansForCouponsFragment) => {
    if (limitPlansList.length === 0) {
      form.setFieldValue('hasBillableMetricLimit', false)
    }
    form.setFieldValue('limitPlansList', [...limitPlansList, plan])
  }

  const attachBillableMetricToCoupon = (billableMetric: BillableMetricsForCouponsFragment) => {
    if (limitBillableMetricsList.length === 0) {
      form.setFieldValue('hasPlanLimit', false)
    }
    form.setFieldValue('limitBillableMetricsList', [...limitBillableMetricsList, billableMetric])
  }

  const couponCloseRedirection = () => {
    if (coupon?.id) {
      navigate(
        generatePath(COUPON_DETAILS_ROUTE, {
          couponId: coupon.id,
          tab: CouponDetailsTabsOptionsEnum.overview,
        }),
      )
    } else {
      navigate(COUPONS_ROUTE)
    }
  }

  useEffect(() => {
    setShouldDisplayDescription(!!coupon?.description)
  }, [coupon?.description])

  useEffect(() => {
    if (errorCode === FORM_ERRORS_ENUM.existingCode) {
      form.setFieldMeta('code', (meta) => ({
        ...meta,
        errorMap: {
          ...meta.errorMap,
          onDynamic: { message: 'text_632a2d437e341dcc76817556' },
        },
      }))
      scrollToTop()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [errorCode])

  useEffect(() => {
    if (errorCode === FORM_ERRORS_ENUM.existingCode) {
      form.setFieldMeta('code', (meta) => ({
        ...meta,
        errorMap: { ...meta.errorMap, onDynamic: undefined },
      }))
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [codeValue])

  useEffect(() => {
    if (
      (formHasPlanLimit || formHasBillableMetricLimit) &&
      limitBillableMetricsList.length === 0 &&
      limitPlansList.length === 0
    ) {
      form.setFieldValue('hasPlanLimit', true)
      form.setFieldValue('hasBillableMetricLimit', true)
    }
  }, [formHasBillableMetricLimit, formHasPlanLimit, limitBillableMetricsList, limitPlansList, form])

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    form.handleSubmit()
  }

  return (
    <div>
      <PageHeader.Wrapper>
        <Typography variant="bodyHl" color="textSecondary" noWrap>
          {translate(isEdition ? 'text_6287a9bdac160c00b2e0fbe7' : 'text_62876e85e32e0300e18030e7')}
        </Typography>
        <Button
          variant="quaternary"
          icon="close"
          data-test="close-create-coupon"
          onClick={() =>
            isDirty
              ? warningDialog.open({
                  title: translate('text_665deda4babaf700d603ea13'),
                  description: translate('text_665dedd557dc3c00c62eb83d'),
                  actionText: translate('text_645388d5bdbd7b00abffa033'),
                  colorVariant: 'danger',
                  onAction: () => couponCloseRedirection(),
                })
              : couponCloseRedirection()
          }
        />
      </PageHeader.Wrapper>
      <form id={COUPONS_FORM_ID} className="min-height-minus-nav flex" onSubmit={handleSubmit}>
        <Main>
          <div>
            {loading ? (
              <FormLoadingSkeleton id="create-coupon" />
            ) : (
              <>
                <div>
                  <Title variant="headline">
                    {translate(
                      isEdition ? 'text_6287a9bdac160c00b2e0fc05' : 'text_62876e85e32e0300e1803106',
                    )}
                  </Title>
                  <Subtitle>
                    {translate(
                      isEdition ? 'text_6287a9bdac160c00b2e0fc0b' : 'text_62876e85e32e0300e180310f',
                    )}
                  </Subtitle>
                </div>
                <Card>
                  <Typography variant="subhead1">
                    {translate('text_62876e85e32e0300e1803115')}
                  </Typography>

                  <NameAndCodeGroup
                    form={form}
                    fields={{ name: 'name', code: 'code' }}
                    disableCodeInput={isEdition && !!coupon?.appliedCouponsCount}
                  />

                  {shouldDisplayDescription ? (
                    <div className="flex items-center">
                      <form.AppField name="description">
                        {(field) => (
                          <field.TextInputField
                            className="mr-3 flex-1"
                            data-test={COUPON_DESCRIPTION_INPUT_TEST_ID}
                            multiline
                            label={translate('text_649e848fa4c023006e94ca32')}
                            placeholder={translate('text_649e85d35208d700473f79c9')}
                            rows="3"
                          />
                        )}
                      </form.AppField>
                      <Tooltip
                        className="mt-6"
                        placement="top-end"
                        title={translate('text_63aa085d28b8510cd46443ff')}
                      >
                        <Button
                          icon="trash"
                          variant="quaternary"
                          onClick={() => {
                            form.setFieldValue('description', '')
                            setShouldDisplayDescription(false)
                          }}
                        />
                      </Tooltip>
                    </div>
                  ) : (
                    <Button
                      className="self-start"
                      startIcon="plus"
                      variant="inline"
                      onClick={() => setShouldDisplayDescription(true)}
                      data-test="show-description"
                    >
                      {translate('text_642d5eb2783a2ad10d670324')}
                    </Button>
                  )}
                </Card>
                <Card>
                  <Typography variant="subhead1">
                    {translate('text_62876e85e32e0300e1803137')}
                  </Typography>

                  <form.AppField name="couponType">
                    {(field) => (
                      <field.ComboBoxField
                        disableClearable
                        label={translate('text_632d68358f1fedc68eed3e5a')}
                        disabled={isEdition && !!coupon?.appliedCouponsCount}
                        data={[
                          {
                            value: CouponTypeEnum.FixedAmount,
                            label: translate('text_632d68358f1fedc68eed3e60'),
                          },
                          {
                            value: CouponTypeEnum.Percentage,
                            label: translate('text_632d68358f1fedc68eed3e66'),
                          },
                        ]}
                      />
                    )}
                  </form.AppField>

                  {couponType === CouponTypeEnum.FixedAmount ? (
                    <div className="flex gap-3">
                      <form.AppField name="amountCents">
                        {(field) => (
                          <field.AmountInputField
                            className="flex-1"
                            currency={amountCurrency || CurrencyEnum.Usd}
                            data-test={COUPON_AMOUNT_INPUT_TEST_ID}
                            beforeChangeFormatter={['positiveNumber']}
                            disabled={isEdition && !!coupon?.appliedCouponsCount}
                            label={translate('text_62978f2c197cea009ab0b7d0')}
                          />
                        )}
                      </form.AppField>
                      <form.AppField name="amountCurrency">
                        {(field) => (
                          <field.ComboBoxField
                            containerClassName="max-w-30 mt-7"
                            disabled={isEdition && !!coupon?.appliedCouponsCount}
                            data={Object.values(CurrencyEnum).map((currencyType) => ({
                              value: currencyType,
                            }))}
                            disableClearable
                          />
                        )}
                      </form.AppField>
                    </div>
                  ) : (
                    <form.AppField name="percentageRate">
                      {(field) => (
                        <field.TextInputField
                          beforeChangeFormatter={['positiveNumber', 'quadDecimal']}
                          data-test={COUPON_PERCENTAGE_INPUT_TEST_ID}
                          disabled={isEdition && !!coupon?.appliedCouponsCount}
                          label={translate('text_632d68358f1fedc68eed3e76')}
                          placeholder={translate('text_632d68358f1fedc68eed3e86')}
                          InputProps={{
                            endAdornment: (
                              <InputAdornment position="end">
                                {translate('text_632d68358f1fedc68eed3e93')}
                              </InputAdornment>
                            ),
                          }}
                        />
                      )}
                    </form.AppField>
                  )}

                  <form.AppField name="frequency">
                    {(field) => (
                      <field.ComboBoxField
                        disabled={isEdition && !!coupon?.appliedCouponsCount}
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
                      />
                    )}
                  </form.AppField>

                  {frequency === CouponFrequency.Forever &&
                    couponType === CouponTypeEnum.FixedAmount && (
                      <Alert type="info">{translate('text_63c83a3476e46bc6ab9d85da')}</Alert>
                    )}

                  {frequency === CouponFrequency.Recurring && (
                    <form.AppField name="frequencyDuration">
                      {(field) => (
                        <field.TextInputField
                          beforeChangeFormatter={['positiveNumber', 'int']}
                          disabled={isEdition && !!coupon?.appliedCouponsCount}
                          label={translate('text_632d68358f1fedc68eed3e80')}
                          placeholder={translate('text_632d68358f1fedc68eed3e88')}
                          InputProps={{
                            endAdornment: (
                              <InputAdornment position="end">
                                {translate('text_632d68358f1fedc68eed3e95')}
                              </InputAdornment>
                            ),
                          }}
                        />
                      )}
                    </form.AppField>
                  )}
                  {couponType === CouponTypeEnum.FixedAmount &&
                    frequency === CouponFrequency.Recurring && (
                      <Alert type="info">{translate('text_632d68358f1fedc68eed3ebd')}</Alert>
                    )}
                </Card>

                <Card className="gap-3">
                  <Typography variant="subhead1">
                    {translate('text_63c83d58e697e8e9236da806')}
                  </Typography>
                  <div className="flex flex-col gap-3">
                    <Checkbox
                      name="isReusable"
                      value={!!reusable}
                      disabled={isEdition && !!coupon?.appliedCouponsCount}
                      label={translate('text_638f48274d41e3f1d01fc16a')}
                      onChange={(_, checked) => {
                        form.setFieldValue('reusable', checked)
                      }}
                    />

                    <Checkbox
                      name="hasLimit"
                      value={expiration === CouponExpiration.TimeLimit}
                      label={translate('text_632d68358f1fedc68eed3eb7')}
                      onChange={(_, checked) => {
                        form.setFieldValue(
                          'expiration',
                          checked ? CouponExpiration.TimeLimit : CouponExpiration.NoExpiration,
                        )
                      }}
                    />

                    {expiration === CouponExpiration.TimeLimit && (
                      <div className="flex gap-3" data-test={COUPON_EXPIRATION_SECTION_TEST_ID}>
                        <Typography
                          variant="body"
                          color="grey700"
                          className="shrink-0"
                          sx={{
                            pt: 2.5,
                          }}
                        >
                          {translate('text_632d68358f1fedc68eed3eb1')}
                        </Typography>
                        <DatePicker
                          disablePast
                          className="flex-1"
                          name="expirationAt"
                          placement="top-end"
                          placeholder={translate('text_632d68358f1fedc68eed3ea5')}
                          error={
                            submissionAttempts > 0 &&
                            expiration === CouponExpiration.TimeLimit &&
                            !expirationAt
                              ? translate('text_1771402708247nxe22ntllvd')
                              : undefined
                          }
                          onChange={(value) => {
                            form.setFieldValue('expirationAt', endOfDayIso(value as string))
                          }}
                          value={expirationAt || ''}
                        />
                      </div>
                    )}
                  </div>

                  <Checkbox
                    className="mb-3"
                    name="hasPlanOrBillableMetricLimit"
                    value={formHasPlanLimit || formHasBillableMetricLimit}
                    disabled={isEdition && !!coupon?.appliedCouponsCount}
                    label={translate('text_64352657267c3d916f9627a4')}
                    onChange={(_, checked) => {
                      if (
                        !checked ||
                        (!limitPlansList.length && !limitBillableMetricsList.length)
                      ) {
                        form.setFieldValue('hasPlanLimit', checked)
                        form.setFieldValue('hasBillableMetricLimit', checked)
                      } else if (!!limitPlansList.length) {
                        form.setFieldValue('hasPlanLimit', checked)
                      } else if (!!limitBillableMetricsList.length) {
                        form.setFieldValue('hasBillableMetricLimit', checked)
                      }
                    }}
                  />

                  {(formHasPlanLimit || formHasBillableMetricLimit) && (
                    <>
                      {!!limitPlansList.length &&
                        limitPlansList.map((plan, i) => (
                          <div
                            className="flex items-center justify-between rounded-xl border border-grey-400 px-4 py-3"
                            key={`limited-plan-${plan.id}`}
                            data-test={`limited-plan-${i}`}
                          >
                            <div className="flex items-center gap-3">
                              <Avatar size="big" variant="connector">
                                <Icon name="board" />
                              </Avatar>
                              <div className="flex flex-col">
                                <Typography variant="bodyHl" color="grey700">
                                  {plan.name}
                                </Typography>
                                <Typography variant="caption" color="grey600">
                                  {plan.code}
                                </Typography>
                              </div>
                            </div>
                            {(!isEdition || !coupon?.appliedCouponsCount) && (
                              <Tooltip
                                placement="top-end"
                                title={translate('text_63d3a201113866a7fa5e6f6d')}
                              >
                                <Button
                                  icon="trash"
                                  variant="quaternary"
                                  size="small"
                                  onClick={() => {
                                    form.setFieldValue(
                                      'limitPlansList',
                                      limitPlansList.filter((p) => p.id !== plan.id),
                                    )
                                  }}
                                  data-test={`delete-limited-plan-${i}`}
                                />
                              </Tooltip>
                            )}
                          </div>
                        ))}

                      {!!limitBillableMetricsList.length &&
                        limitBillableMetricsList.map((billableMetric, i) => (
                          <div
                            className="flex items-center justify-between rounded-xl border border-grey-400 px-4 py-3"
                            key={`limited-billable-metric-${billableMetric.id}`}
                            data-test={`limited-billable-metric-${i}`}
                          >
                            <div className="flex items-center gap-3">
                              <Avatar size="big" variant="connector">
                                <Icon name="board" />
                              </Avatar>
                              <div className="flex flex-col">
                                <Typography variant="bodyHl" color="grey700">
                                  {billableMetric.name}
                                </Typography>
                                <Typography variant="caption" color="grey600">
                                  {billableMetric.code}
                                </Typography>
                              </div>
                            </div>
                            {(!isEdition || !coupon?.appliedCouponsCount) && (
                              <Tooltip
                                placement="top-end"
                                title={translate('text_64352657267c3d916f9627c0')}
                              >
                                <Button
                                  icon="trash"
                                  variant="quaternary"
                                  size="small"
                                  onClick={() => {
                                    form.setFieldValue(
                                      'limitBillableMetricsList',
                                      limitBillableMetricsList.filter(
                                        (b) => b.id !== billableMetric.id,
                                      ),
                                    )
                                  }}
                                  data-test={`delete-limited-billable-metric-${i}`}
                                />
                              </Tooltip>
                            )}
                          </div>
                        ))}

                      {(!isEdition || !coupon?.appliedCouponsCount) && (
                        <div className="flex flex-row flex-wrap gap-4">
                          <Button
                            variant="inline"
                            startIcon="plus"
                            disabled={formHasBillableMetricLimit && !formHasPlanLimit}
                            onClick={() =>
                              openAddPlanToCouponDialog({
                                onSubmit: attachPlanToCoupon,
                                attachedPlansIds: limitPlansList.map((p) => p.id),
                              })
                            }
                            data-test="add-plan-limit"
                          >
                            {translate('text_63d3a201113866a7fa5e6f6b')}
                          </Button>
                          <Button
                            variant="inline"
                            startIcon="plus"
                            disabled={formHasPlanLimit && !formHasBillableMetricLimit}
                            onClick={() =>
                              openAddBillableMetricToCouponDialog({
                                onSubmit: attachBillableMetricToCoupon,
                                attachedBillableMetricsIds: limitBillableMetricsList.map(
                                  (b) => b.id,
                                ),
                              })
                            }
                            data-test="add-billable-metric-limit"
                          >
                            {translate('text_64352657267c3d916f9627bc')}
                          </Button>
                        </div>
                      )}

                      {submissionAttempts > 0 &&
                        limitPlansList.length === 0 &&
                        limitBillableMetricsList.length === 0 && (
                          <Alert type="danger" data-test={COUPON_LIMIT_ERROR_TEST_ID}>
                            {translate('text_1771402708247jyowmhc424h')}
                          </Alert>
                        )}
                    </>
                  )}
                </Card>

                <div className="px-6 pb-20">
                  <form.AppForm>
                    <form.SubmitButton fullWidth size="large" dataTest="submit">
                      {translate(
                        isEdition
                          ? 'text_6287a9bdac160c00b2e0fc6b'
                          : 'text_62876e85e32e0300e180317d',
                      )}
                    </form.SubmitButton>
                  </form.AppForm>
                </div>
              </>
            )}
          </div>
        </Main>
        <Side>
          <CouponCodeSnippet
            loading={loading}
            coupon={formValues as unknown as CreateCouponInput}
            hasPlanLimit={formHasPlanLimit}
            limitPlansList={limitPlansList}
            hasBillableMetricLimit={formHasBillableMetricLimit}
            limitBillableMetricsList={limitBillableMetricsList}
          />
        </Side>
      </form>
    </div>
  )
}

export default CreateCoupon
