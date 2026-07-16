import { gql } from '@apollo/client'
import { InputAdornment } from '@mui/material'
import { useCallback, useMemo, useRef } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { ChargeTable } from '~/components/designSystem/Table'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { WarningDialog, WarningDialogRef } from '~/components/designSystem/WarningDialog'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { addToast } from '~/core/apolloClient'
import { CustomerSubscriptionDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { getCurrencySymbol } from '~/core/formats/intlFormatNumber'
import {
  CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE,
  PLAN_SUBSCRIPTION_DETAILS_ROUTE,
  useNavigate,
} from '~/core/router'
import {
  CurrencyEnum,
  useGetSubscriptionForProgressiveBillingFormQuery,
  UseSubscriptionForProgressiveBillingFormFragmentDoc,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { FormLoadingSkeleton } from '~/styles/mainObjectsForm'

import {
  ERROR_ASCENDING_ORDER,
  useProgressiveBillingTanstackForm,
} from './useProgressiveBillingTanstackForm'

// Test ID constants
export const PROGRESSIVE_BILLING_FORM_TEST_ID = 'progressive-billing-form'
export const PROGRESSIVE_BILLING_DISABLED_SWITCH_TEST_ID = 'progressive-billing-disabled-switch'
export const PROGRESSIVE_BILLING_ADD_THRESHOLD_BUTTON_TEST_ID =
  'progressive-billing-add-threshold-button'
export const PROGRESSIVE_BILLING_HAS_RECURRING_SWITCH_TEST_ID =
  'progressive-billing-has-recurring-switch'
export const PROGRESSIVE_BILLING_CANCEL_BUTTON_TEST_ID = 'progressive-billing-cancel-button'
export const PROGRESSIVE_BILLING_SUBMIT_BUTTON_TEST_ID = 'progressive-billing-submit-button'
export const PROGRESSIVE_BILLING_CLOSE_BUTTON_TEST_ID = 'progressive-billing-close-button'
export const PROGRESSIVE_BILLING_INFO_ALERT_TEST_ID = 'progressive-billing-info-alert'

gql`
  query getSubscriptionForProgressiveBillingForm($subscriptionId: ID!) {
    subscription(id: $subscriptionId) {
      id
      ...UseSubscriptionForProgressiveBillingForm
      plan {
        id
        amountCurrency
      }
    }
  }

  mutation updateSubscriptionProgressiveBilling($input: UpdateSubscriptionInput!) {
    updateSubscription(input: $input) {
      id
      progressiveBillingDisabled
      usageThresholds {
        id
        amountCents
        recurring
        thresholdDisplayName
      }
    }
  }

  ${UseSubscriptionForProgressiveBillingFormFragmentDoc}
`

const SubscriptionProgressiveBillingForm = () => {
  const { customerId = '', planId = '', subscriptionId = '' } = useParams()
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const warningDirtyAttributesDialogRef = useRef<WarningDialogRef>(null)

  const { data: subscriptionData, loading: subscriptionLoading } =
    useGetSubscriptionForProgressiveBillingFormQuery({
      variables: { subscriptionId },
      skip: !subscriptionId,
    })

  const subscription = subscriptionData?.subscription
  const currency = subscription?.plan?.amountCurrency || CurrencyEnum.Usd

  const onLeave = useCallback(() => {
    const tab = CustomerSubscriptionDetailsTabsOptionsEnum.progressiveBilling

    if (customerId) {
      navigate(
        generatePath(CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE, {
          customerId,
          subscriptionId,
          tab,
        }),
      )
    } else if (planId) {
      navigate(
        generatePath(PLAN_SUBSCRIPTION_DETAILS_ROUTE, {
          planId,
          subscriptionId,
          tab,
        }),
      )
    }
  }, [customerId, navigate, planId, subscriptionId])

  const onSuccess = useCallback(() => {
    addToast({
      severity: 'success',
      translateKey: 'text_1738071730498pqk8rj3l2sm',
    })
    onLeave()
  }, [onLeave])

  const {
    form,
    progressiveBillingDisabled,
    nonRecurringThresholds,
    hasRecurring,
    recurringThreshold,
    isDirty,
    handleAddThreshold,
    handleDeleteThreshold,
    handleSubmit,
  } = useProgressiveBillingTanstackForm({
    subscriptionId,
    subscription,
    currency,
    onSuccess,
  })

  const nonRecurringThresholdsColumns = useMemo(
    () => [
      {
        size: 224,
        content: (_: unknown, i: number) => (
          <Typography className="px-4" variant="captionHl" noWrap>
            {translate(i === 0 ? 'text_1724234174944p8zi54j192m' : 'text_1724179887723917j8ezkd9v')}
          </Typography>
        ),
      },
      {
        size: 197,
        title: (
          <Typography className="px-4" variant="captionHl">
            {translate('text_1724179887723eh12a0kqbdw')}
          </Typography>
        ),
        content: (_: unknown, i: number) => (
          <form.AppField name={`nonRecurringThresholds[${i}].amountCents`}>
            {(field) => {
              // Check if this field has the ascending order error
              const hasAscendingOrderError = field.state.meta.errors.some(
                (e) => e?.message === ERROR_ASCENDING_ORDER,
              )

              return (
                <Tooltip
                  placement="top"
                  title={translate('text_1724252232460i4tv7384iiy', {
                    value: nonRecurringThresholds?.[i - 1]?.amountCents,
                  })}
                  disableHoverListener={!hasAscendingOrderError}
                >
                  <field.AmountInputField
                    variant="outlined"
                    beforeChangeFormatter={['positiveNumber']}
                    currency={currency}
                    displayErrorText={false}
                    InputProps={{
                      startAdornment: (
                        <InputAdornment position="start">
                          {getCurrencySymbol(currency)}
                        </InputAdornment>
                      ),
                    }}
                  />
                </Tooltip>
              )
            }}
          </form.AppField>
        ),
      },
      {
        size: 197,
        title: (
          <Typography className="px-4" variant="captionHl">
            {translate('text_17241798877234jhvoho4ci9')}
          </Typography>
        ),
        content: (_: unknown, i: number) => (
          <form.AppField name={`nonRecurringThresholds[${i}].thresholdDisplayName`}>
            {(field) => (
              <field.TextInputField
                variant="outlined"
                placeholder={translate('text_645bb193927b375079d28ace')}
              />
            )}
          </form.AppField>
        ),
      },
    ],
    [currency, form, nonRecurringThresholds, translate],
  )

  const recurringThresholdColumns = useMemo(
    () => [
      {
        size: 224,
        content: () => (
          <Typography className="px-4" variant="captionHl" noWrap>
            {translate('text_17241798877230y851fdxzqu')}
          </Typography>
        ),
      },
      {
        size: 197,
        content: () => (
          <form.AppField name="recurringThreshold.amountCents">
            {(field) => (
              <field.AmountInputField
                variant="outlined"
                beforeChangeFormatter={['positiveNumber']}
                currency={currency}
                displayErrorText={false}
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">{getCurrencySymbol(currency)}</InputAdornment>
                  ),
                }}
              />
            )}
          </form.AppField>
        ),
      },
      {
        size: 197,
        content: () => (
          <form.AppField name="recurringThreshold.thresholdDisplayName">
            {(field) => (
              <field.TextInputField
                variant="outlined"
                placeholder={translate('text_645bb193927b375079d28ace')}
              />
            )}
          </form.AppField>
        ),
      },
    ],
    [currency, form, translate],
  )

  const handleAbort = () => {
    if (isDirty) {
      warningDirtyAttributesDialogRef.current?.openDialog()
    } else {
      onLeave()
    }
  }

  return (
    <>
      <CenteredPage.Wrapper>
        <form
          id="create-subscription-progressive-billing"
          className="flex size-full min-h-full flex-col overflow-auto"
          data-test={PROGRESSIVE_BILLING_FORM_TEST_ID}
          onSubmit={async (e) => {
            e.preventDefault()
            await handleSubmit(e)
          }}
        >
          <CenteredPage.Header>
            <Typography variant="bodyHl" color="textSecondary" noWrap>
              {translate('text_1738071730498edit4pb8hzw')}
            </Typography>

            <Button
              data-test={PROGRESSIVE_BILLING_CLOSE_BUTTON_TEST_ID}
              icon="close"
              variant="quaternary"
              onClick={handleAbort}
            />
          </CenteredPage.Header>

          <CenteredPage.Container>
            {subscriptionLoading && <FormLoadingSkeleton id="progressive-billing-form-skeleton" />}

            {!subscriptionLoading && (
              <div className="flex flex-col gap-12">
                <div className="flex flex-col gap-2">
                  <Typography variant="headline">
                    {translate('text_1738071730498edit4pb8hzw')}
                  </Typography>
                  <Typography variant="body">
                    {translate('text_1770040134341pf8pbxr80fz')}
                  </Typography>
                </div>

                <div className="flex flex-col gap-6">
                  <div className="flex flex-col gap-2">
                    <Typography variant="subhead1">
                      {translate('text_17696267519471sodhgj81od')}
                    </Typography>
                    <Typography variant="caption">
                      {translate('text_1769626753039lmsvielfb69')}
                    </Typography>
                  </div>

                  <form.AppField name="progressiveBillingDisabled">
                    {(field) => (
                      <field.SwitchField
                        dataTest={PROGRESSIVE_BILLING_DISABLED_SWITCH_TEST_ID}
                        label={translate('text_177004013434274m1zrl0bo5')}
                        subLabel={translate('text_1770040134342f6nljdn0pqc')}
                      />
                    )}
                  </form.AppField>

                  {!progressiveBillingDisabled && (
                    <>
                      <div className="flex flex-col">
                        <Button
                          data-test={PROGRESSIVE_BILLING_ADD_THRESHOLD_BUTTON_TEST_ID}
                          className="mb-2 ml-auto"
                          startIcon="plus"
                          variant="inline"
                          onClick={handleAddThreshold}
                        >
                          {translate('text_1724233213997l2ksi40t8q6')}
                        </Button>
                        <div className="-mx-4 -mb-1 overflow-auto px-4 pb-1">
                          <ChargeTable
                            className="w-full"
                            name="progressive-billing-thresholds"
                            data={nonRecurringThresholds.map((t, i) => ({
                              ...t,
                              index: i,
                              disabledDelete: nonRecurringThresholds.length === 1,
                            }))}
                            onDeleteRow={(_, i) => handleDeleteThreshold(i)}
                            deleteTooltipContent={translate('text_17242522324608198c2vblmw')}
                            columns={nonRecurringThresholdsColumns}
                          />
                        </div>
                      </div>

                      <form.AppField name="hasRecurring">
                        {(field) => (
                          <field.SwitchField
                            dataTest={PROGRESSIVE_BILLING_HAS_RECURRING_SWITCH_TEST_ID}
                            label={translate('text_1724234174945ztq15pvmty3')}
                            subLabel={translate('text_172423417494563qf45qet2d')}
                          />
                        )}
                      </form.AppField>

                      {hasRecurring && (
                        <div className="-mx-4 -mb-1 overflow-auto px-4 py-1">
                          <ChargeTable
                            className="w-full"
                            name="progressive-billing-recurring"
                            columns={recurringThresholdColumns}
                            data={[recurringThreshold]}
                          />
                        </div>
                      )}

                      <Alert data-test={PROGRESSIVE_BILLING_INFO_ALERT_TEST_ID} type="info">
                        {translate('text_1724252232460iqofvwnpgnx')}
                      </Alert>
                    </>
                  )}
                </div>
              </div>
            )}
          </CenteredPage.Container>

          <CenteredPage.StickyFooter>
            <Button
              data-test={PROGRESSIVE_BILLING_CANCEL_BUTTON_TEST_ID}
              size="large"
              variant="quaternary"
              onClick={handleAbort}
            >
              {translate('text_62e79671d23ae6ff149de968')}
            </Button>

            <form.AppForm>
              <form.SubmitButton dataTest={PROGRESSIVE_BILLING_SUBMIT_BUTTON_TEST_ID}>
                {translate('text_17432414198706rdwf76ek3u')}
              </form.SubmitButton>
            </form.AppForm>
          </CenteredPage.StickyFooter>
        </form>
      </CenteredPage.Wrapper>

      <WarningDialog
        ref={warningDirtyAttributesDialogRef}
        title={translate('text_665deda4babaf700d603ea13')}
        description={translate('text_665dedd557dc3c00c62eb83d')}
        continueText={translate('text_6244277fe0975300fe3fb94c')}
        onContinue={onLeave}
      />
    </>
  )
}

export default SubscriptionProgressiveBillingForm
