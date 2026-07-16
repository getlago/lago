import Box from '@mui/material/Box'
import InputAdornment from '@mui/material/InputAdornment'
import Stack from '@mui/material/Stack'
import { FormikProps, getIn } from 'formik'
import { Icon } from 'lago-design-system'
import { get } from 'lodash'
import { DateTime } from 'luxon'
import { FC, useMemo, useState } from 'react'

import { Accordion } from '~/components/designSystem/Accordion'
import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import {
  AmountInputField,
  ButtonSelector,
  ComboBox,
  ComboBoxField,
  DatePickerField,
  Switch,
  TextInputField,
} from '~/components/form'
import { PaymentMethodsInvoiceSettings } from '~/components/paymentMethodsInvoiceSettings/PaymentMethodsInvoiceSettings'
import { ViewTypeEnum } from '~/components/paymentMethodsInvoiceSettings/types'
import { getWordingForWalletCreationAlert } from '~/components/wallets/utils'
import {
  ADD_METADATA_DATA_TEST,
  RECURRING_IGNORE_PAID_TOPUP_LIMITS_SWITCH_DATA_TEST,
  RECURRING_INVOICE_REQUIRES_SUCCESSFUL_PAYMENT_SWITCH_DATA_TEST,
  RECURRING_TOPUP_TYPE_DATA_TEST,
  SHOW_RECURRING_EXPIRATION_AT_DATA_TEST,
} from '~/components/wallets/utils/dataTestConstants'
import { dateErrorCodes, FORM_TYPE_ENUM, getIntervalTranslationKey } from '~/core/constants/form'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { intlFormatDateTime } from '~/core/timezone'
import {
  METADATA_VALUE_MAX_LENGTH_DEFAULT,
  MetadataErrorsEnum,
} from '~/formValidation/metadataSchema'
import {
  CurrencyEnum,
  GetCustomerInfosForWalletFormQuery,
  RecurringTransactionIntervalEnum,
  RecurringTransactionMethodEnum,
  RecurringTransactionTriggerEnum,
  UpdateRecurringTransactionRuleInput,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { topUpAmountError, walletFormErrorCodes } from '~/pages/wallet/form'
import { TWalletDataForm } from '~/pages/wallet/types'

const AccordionSummary: FC<{ label: string; isValid: boolean; onDelete: VoidFunction }> = ({
  label,
  isValid,
  onDelete,
}) => {
  return (
    <Stack
      width="100%"
      flexDirection="row"
      alignItems="center"
      justifyContent="space-between"
      spacing={3}
    >
      <Box>
        <Typography color="grey700">{label}</Typography>
      </Box>
      <Stack marginTop="0 !important" direction="row" alignItems="center" spacing={3}>
        <Icon name="validate-filled" color={isValid ? 'success' : 'disabled'} />
        <Button icon="trash" variant="quaternary" size="small" onClick={onDelete} />
      </Stack>
    </Stack>
  )
}

const inputAdornment = (endLabel: string) => {
  return {
    InputProps: {
      endAdornment: <InputAdornment position="end">{endLabel}</InputAdornment>,
    },
  }
}

const formatCreditsToCurrency = (rate: string, credits?: string, currency?: CurrencyEnum) => {
  return intlFormatNumber(isNaN(Number(credits)) ? 0 : Number(credits) * Number(rate), {
    currencyDisplay: 'symbol',
    currency: currency || CurrencyEnum.Usd,
  })
}

const DEFAULT_RULES: UpdateRecurringTransactionRuleInput = {
  lagoId: undefined,
  method: RecurringTransactionMethodEnum.Fixed,
  trigger: RecurringTransactionTriggerEnum.Threshold,
  interval: RecurringTransactionIntervalEnum.Weekly,
  grantedCredits: '',
  paidCredits: '',
  thresholdCredits: '',
  targetOngoingBalance: null,
  grantsTargetTopUp: null,
  startedAt: DateTime.now().toISO(),
  invoiceRequiresSuccessfulPayment: false,
}

interface TopUpSectionProps {
  formikProps: FormikProps<TWalletDataForm>
  formType: keyof typeof FORM_TYPE_ENUM
  customerData?: GetCustomerInfosForWalletFormQuery
  isRecurringTopUpEnabled: boolean
  setIsRecurringTopUpEnabled: (value: boolean) => void
}

export const TopUpSection: FC<TopUpSectionProps> = ({
  formikProps,
  customerData,
  isRecurringTopUpEnabled,
  setIsRecurringTopUpEnabled,
}) => {
  const { isPremium } = useCurrentUser()
  const { translate } = useInternationalization()
  const { open: openPremiumWarningDialog } = usePremiumWarningDialog()
  const [accordionIsOpen, setAccordionIsOpen] = useState(false)

  const recurringTransactionRules = formikProps.values?.recurringTransactionRules?.[0]

  const canDisplayAccordionAlert =
    !!recurringTransactionRules?.method &&
    ((recurringTransactionRules?.trigger === RecurringTransactionTriggerEnum.Interval &&
      !!recurringTransactionRules?.interval) ||
      (recurringTransactionRules?.trigger === RecurringTransactionTriggerEnum.Threshold &&
        !!recurringTransactionRules?.thresholdCredits))

  const hasRecurringTransactionRulesErrors = useMemo(() => {
    return formikProps?.errors?.recurringTransactionRules?.length
  }, [formikProps?.errors?.recurringTransactionRules])

  const paidTopUpMinAmountCents = formikProps?.values?.paidTopUpMinAmountCents
  const paidTopUpMaxAmountCents = formikProps?.values?.paidTopUpMaxAmountCents

  const recurringPaidCreditsError = topUpAmountError({
    rateAmount: formikProps?.values?.rateAmount,
    paidCredits: formikProps?.values?.recurringTransactionRules?.[0]?.paidCredits || '',
    paidTopUpMinAmountCents,
    paidTopUpMaxAmountCents,
    currency: formikProps?.values?.currency,
    skip: !!formikProps?.values?.recurringTransactionRules?.[0]?.ignorePaidTopUpLimits,
    translate,
  })

  const hasMinMax =
    !!formikProps?.values?.paidTopUpMinAmountCents || !!formikProps?.values?.paidTopUpMaxAmountCents

  return (
    <>
      {(customerData?.customer?.externalId || customerData?.customer?.id) && (
        <section className="flex w-full flex-col gap-6 pb-12 shadow-b">
          <div className="flex flex-col gap-1">
            <Typography variant="subhead1">{translate('text_17634566456760qoj7hs7jrh')}</Typography>
          </div>
          <PaymentMethodsInvoiceSettings
            customer={customerData?.customer}
            form={formikProps}
            viewType={ViewTypeEnum.WalletTopUp}
          />
        </section>
      )}

      <section className="flex w-full flex-col gap-6">
        <div className="flex flex-col gap-1">
          <Typography variant="subhead1">{translate('text_1741101674268ag60i0cc55m')}</Typography>
          <Typography variant="caption">{translate('text_6657be42151661006d2f3b95')}</Typography>
        </div>
        {!isRecurringTopUpEnabled ? (
          <Box>
            <Button
              variant="inline"
              startIcon="plus"
              endIcon={isPremium ? undefined : 'sparkles'}
              onClick={() => {
                if (isPremium) {
                  formikProps.setFieldValue('recurringTransactionRules.0', DEFAULT_RULES)
                  setIsRecurringTopUpEnabled(true)
                  setAccordionIsOpen(true)
                } else {
                  openPremiumWarningDialog()
                }
              }}
            >
              {translate('text_6657be42151661006d2f3b96')}
            </Button>
          </Box>
        ) : (
          <Accordion
            noContentMargin
            initiallyOpen={accordionIsOpen}
            summary={
              <AccordionSummary
                label={translate('text_6657c29c84ad4500ad764ed6')}
                isValid={!hasRecurringTransactionRulesErrors}
                onDelete={async () => {
                  formikProps.setFieldValue('recurringTransactionRules', undefined)
                  setIsRecurringTopUpEnabled(false)
                }}
              />
            }
          >
            <div className="flex flex-col gap-6 p-4 shadow-b">
              <ComboBox
                name="recurringTransactionRules.0.method"
                disableClearable
                sortValues
                placeholder={translate('text_6657c29c84ad4500ad764ed8')}
                label={translate('text_6657c29c84ad4500ad764ed7')}
                data={[
                  {
                    label: translate('text_6657cdd8cea6bf010e1ce128'),
                    value: RecurringTransactionMethodEnum.Fixed,
                  },
                  {
                    label: translate('text_6657c34670561c0127132da4'),
                    value: RecurringTransactionMethodEnum.Target,
                  },
                ]}
                value={formikProps.values.recurringTransactionRules?.[0].method as string}
                onChange={(value) => {
                  formikProps.setFieldValue(
                    'recurringTransactionRules.0.paidCredits',
                    DEFAULT_RULES.paidCredits,
                  )
                  formikProps.setFieldValue(
                    'recurringTransactionRules.0.grantedCredits',
                    DEFAULT_RULES.grantedCredits,
                  )
                  formikProps.setFieldValue(
                    'recurringTransactionRules.0.targetOngoingBalance',
                    DEFAULT_RULES.targetOngoingBalance,
                  )
                  formikProps.setFieldValue(
                    'recurringTransactionRules.0.grantsTargetTopUp',
                    value === RecurringTransactionMethodEnum.Target ? false : null,
                  )

                  formikProps.setFieldValue('recurringTransactionRules.0.method', value)
                }}
              />

              <TextInputField
                name="recurringTransactionRules.0.transactionName"
                formikProps={formikProps}
                label={translate('text_17580145853389xkffv9cs1d')}
                placeholder={translate('text_17580145853390n3v83gao69')}
                helperText={translate('text_1758014585339r3kd52x7r58')}
              />

              {recurringTransactionRules?.method === RecurringTransactionMethodEnum.Fixed && (
                <>
                  <AmountInputField
                    name="recurringTransactionRules.0.paidCredits"
                    currency={formikProps.values.currency}
                    beforeChangeFormatter={['positiveNumber']}
                    label={translate('text_62e79671d23ae6ff149de944')}
                    formikProps={formikProps}
                    silentError={true}
                    error={recurringPaidCreditsError?.label}
                    helperText={translate('text_62d18855b22699e5cf55f88b', {
                      paidCredits: formatCreditsToCurrency(
                        formikProps.values.rateAmount,
                        recurringTransactionRules?.paidCredits as string | undefined,
                        formikProps.values.currency,
                      ),
                    })}
                    {...inputAdornment(translate('text_62d18855b22699e5cf55f889'))}
                  />

                  {formikProps.values.recurringTransactionRules?.[0].paidCredits && (
                    <>
                      {hasMinMax && (
                        <Switch
                          name="recurringTransactionRules.0.ignorePaidTopUpLimits"
                          onChange={(value) => {
                            formikProps.setFieldValue(
                              'recurringTransactionRules.0.ignorePaidTopUpLimits',
                              value,
                            )
                          }}
                          checked={
                            formikProps.values.recurringTransactionRules?.[0]
                              .ignorePaidTopUpLimits || false
                          }
                          label={translate('text_1758285686646ty4gyil56oi')}
                          subLabel={translate('text_1758285686647hxpjldry342')}
                          data-test={RECURRING_IGNORE_PAID_TOPUP_LIMITS_SWITCH_DATA_TEST}
                        />
                      )}

                      <Switch
                        name="recurringTransactionRules.0.invoiceRequiresSuccessfulPayment"
                        onChange={(value) => {
                          formikProps.setFieldValue(
                            'recurringTransactionRules.0.invoiceRequiresSuccessfulPayment',
                            value,
                          )
                        }}
                        checked={
                          formikProps.values.recurringTransactionRules?.[0]
                            .invoiceRequiresSuccessfulPayment ??
                          (DEFAULT_RULES.invoiceRequiresSuccessfulPayment as boolean)
                        }
                        label={translate('text_66a8aed1c3e07b277ec3990d')}
                        subLabel={translate('text_66a8aed1c3e07b277ec3990f')}
                        data-test={RECURRING_INVOICE_REQUIRES_SUCCESSFUL_PAYMENT_SWITCH_DATA_TEST}
                      />
                    </>
                  )}

                  <AmountInputField
                    name="recurringTransactionRules.0.grantedCredits"
                    currency={formikProps.values.currency}
                    beforeChangeFormatter={['positiveNumber']}
                    label={translate('text_62e79671d23ae6ff149de954')}
                    formikProps={formikProps}
                    silentError={true}
                    helperText={translate('text_62d18855b22699e5cf55f893', {
                      grantedCredits: formatCreditsToCurrency(
                        formikProps.values.rateAmount,
                        recurringTransactionRules?.grantedCredits as string | undefined,
                        formikProps.values.currency,
                      ),
                    })}
                    {...inputAdornment(translate('text_62d18855b22699e5cf55f889'))}
                  />
                </>
              )}

              {recurringTransactionRules?.method === RecurringTransactionMethodEnum.Target && (
                <>
                  <ButtonSelector
                    data-test={RECURRING_TOPUP_TYPE_DATA_TEST}
                    label={translate('text_1780047483204bk0fhgkeisn')}
                    options={[
                      {
                        value: false,
                        label: translate('text_1780047483205fq5350ul8l9'),
                      },
                      {
                        value: true,
                        label: translate('text_1780047483205pks944o79kd'),
                      },
                    ]}
                    value={recurringTransactionRules?.grantsTargetTopUp ?? false}
                    onChange={(value) => {
                      formikProps.setFieldValue(
                        'recurringTransactionRules.0.grantsTargetTopUp',
                        value,
                      )
                    }}
                  />

                  <AmountInputField
                    name="recurringTransactionRules.0.targetOngoingBalance"
                    currency={formikProps.values.currency}
                    beforeChangeFormatter={['positiveNumber']}
                    label={translate('text_6657c34670561c0127132da5')}
                    formikProps={formikProps}
                    error={
                      get(
                        formikProps.errors,
                        'recurringTransactionRules.0.targetOngoingBalance',
                      ) === walletFormErrorCodes.targetOngoingBalanceShouldBeGreaterThanThreshold
                        ? translate('text_66584178ee91f801012606a6')
                        : undefined
                    }
                    {...inputAdornment(translate('text_62d18855b22699e5cf55f889'))}
                  />
                  {formikProps.values.recurringTransactionRules?.[0].targetOngoingBalance && (
                    <Switch
                      name="recurringTransactionRules.0.invoiceRequiresSuccessfulPayment"
                      onChange={(value) => {
                        formikProps.setFieldValue(
                          'recurringTransactionRules.0.invoiceRequiresSuccessfulPayment',
                          value,
                        )
                      }}
                      checked={
                        formikProps.values.recurringTransactionRules?.[0]
                          .invoiceRequiresSuccessfulPayment ??
                        (DEFAULT_RULES.invoiceRequiresSuccessfulPayment as boolean)
                      }
                      label={translate('text_66a8aed1c3e07b277ec3990d')}
                      subLabel={translate('text_66a8aed1c3e07b277ec3990f')}
                    />
                  )}
                </>
              )}

              <div className="flex w-full flex-row gap-3">
                <ComboBox
                  containerClassName="flex-1"
                  disableClearable
                  sortValues
                  placeholder={translate('text_6657c29c84ad4500ad764ee2')}
                  label={translate('text_6657c29c84ad4500ad764ee1')}
                  name="recurringTransactionRules.0.trigger"
                  data={[
                    {
                      label: translate('text_65201b8216455901fe273dc1'),
                      value: RecurringTransactionTriggerEnum.Interval,
                    },
                    {
                      label: translate('text_6560809c38fb9de88d8a5315'),
                      value: RecurringTransactionTriggerEnum.Threshold,
                    },
                  ]}
                  value={formikProps.values.recurringTransactionRules?.[0].trigger}
                  onChange={(value) => {
                    if (value === RecurringTransactionTriggerEnum.Interval) {
                      formikProps.setFieldValue(
                        'recurringTransactionRules.0.thresholdCredits',
                        DEFAULT_RULES.thresholdCredits,
                      )
                    }

                    if (value === RecurringTransactionTriggerEnum.Threshold) {
                      formikProps.setFieldValue(
                        'recurringTransactionRules.0.interval',
                        DEFAULT_RULES.interval,
                      )
                    }

                    formikProps.setFieldValue('recurringTransactionRules.0.trigger', value)
                  }}
                />
                {recurringTransactionRules?.trigger ===
                  RecurringTransactionTriggerEnum.Interval && (
                  <>
                    <ComboBoxField
                      containerClassName="flex-1"
                      name="recurringTransactionRules.0.interval"
                      disableClearable
                      sortValues={false}
                      formikProps={formikProps}
                      label={translate('text_65201b8216455901fe273dc1')}
                      placeholder={translate('text_6560c252c4f33631aff1ab27')}
                      data={[
                        {
                          label: translate(
                            getIntervalTranslationKey[RecurringTransactionIntervalEnum.Weekly],
                          ),
                          value: RecurringTransactionIntervalEnum.Weekly,
                        },
                        {
                          label: translate(
                            getIntervalTranslationKey[RecurringTransactionIntervalEnum.Monthly],
                          ),
                          value: RecurringTransactionIntervalEnum.Monthly,
                        },
                        {
                          label: translate(
                            getIntervalTranslationKey[RecurringTransactionIntervalEnum.Quarterly],
                          ),
                          value: RecurringTransactionIntervalEnum.Quarterly,
                        },
                        {
                          label: translate(
                            getIntervalTranslationKey[RecurringTransactionIntervalEnum.Semiannual],
                          ),
                          value: RecurringTransactionIntervalEnum.Semiannual,
                        },
                        {
                          label: translate(
                            getIntervalTranslationKey[RecurringTransactionIntervalEnum.Yearly],
                          ),
                          value: RecurringTransactionIntervalEnum.Yearly,
                        },
                      ]}
                    />
                    <div className="flex-1">
                      <DatePickerField
                        name="recurringTransactionRules.0.startedAt"
                        placement="top-end"
                        formikProps={formikProps}
                        label={translate('text_66599bfb69fba1010535c5c2')}
                        placeholder={translate('text_62d18855b22699e5cf55f899')}
                      />
                    </div>
                  </>
                )}
                {recurringTransactionRules?.trigger ===
                  RecurringTransactionTriggerEnum.Threshold && (
                  <AmountInputField
                    className="flex-[2_2_0%]"
                    name="recurringTransactionRules.0.thresholdCredits"
                    currency={formikProps.values.currency}
                    label={translate('text_6560809c38fb9de88d8a5315')}
                    formikProps={formikProps}
                    error={
                      get(formikProps.errors, 'recurringTransactionRules.0.thresholdCredits') ===
                      walletFormErrorCodes.thresholdShouldBeLessThanTargetOngoingBalance
                        ? translate('text_66584178ee91f801012606ac')
                        : undefined
                    }
                    {...inputAdornment(translate('text_62d18855b22699e5cf55f889'))}
                  />
                )}
              </div>

              {canDisplayAccordionAlert && (
                <Alert type="info">
                  {getWordingForWalletCreationAlert({
                    translate,
                    currency: formikProps.values?.currency,
                    customerTimezone: customerData?.customer?.timezone,
                    recurringRulesValues: recurringTransactionRules,
                    walletValues: formikProps.values,
                  })}
                </Alert>
              )}

              {!!recurringTransactionRules?.expirationAt ||
              recurringTransactionRules?.expirationAt === '' ? (
                <div className="flex items-center gap-4">
                  <DatePickerField
                    className="grow"
                    disablePast
                    name="recurringTransactionRules.0.expirationAt"
                    placement="top-end"
                    label={translate('text_62d18855b22699e5cf55f897')}
                    placeholder={translate('text_62d18855b22699e5cf55f899')}
                    helperText={translate('text_1741689608703zttwsl2nnq2')}
                    formikProps={formikProps}
                    error={
                      getIn(formikProps.errors, 'recurringTransactionRules.0.expirationAt') ===
                      dateErrorCodes.shouldBeInFuture
                        ? translate('text_630ccd87b251590eaa5f9831', {
                            date: intlFormatDateTime(DateTime.now().toISO()).date,
                          })
                        : undefined
                    }
                  />
                  <Tooltip placement="top-end" title={translate('text_63aa085d28b8510cd46443ff')}>
                    <Button
                      icon="trash"
                      variant="quaternary"
                      onClick={() => {
                        formikProps.setFieldValue('recurringTransactionRules.0.expirationAt', null)
                      }}
                    />
                  </Tooltip>
                </div>
              ) : (
                <Button
                  className="self-start"
                  startIcon="plus"
                  variant="inline"
                  onClick={() =>
                    formikProps.setFieldValue('recurringTransactionRules.0.expirationAt', '')
                  }
                  data-test={SHOW_RECURRING_EXPIRATION_AT_DATA_TEST}
                >
                  {translate('text_6560809c38fb9de88d8a517e')}
                </Button>
              )}
            </div>

            {(customerData?.customer?.externalId || customerData?.customer?.id) && (
              <div className="flex flex-col gap-6 p-4 shadow-b">
                <PaymentMethodsInvoiceSettings
                  customer={customerData?.customer}
                  form={formikProps}
                  formFieldBasePath="recurringTransactionRules.0"
                  viewType={ViewTypeEnum.WalletRecurringTopUp}
                />
              </div>
            )}

            <div className="flex flex-col gap-6 p-4">
              <div>
                <Typography variant="bodyHl" color="textSecondary">
                  {translate('text_63fcc3218d35b9377840f59b')}
                </Typography>
                <Typography variant="caption">
                  {translate('text_1741690423581n3e4cj019jg')}
                </Typography>
              </div>

              {recurringTransactionRules?.transactionMetadata?.map((_metadata, index) => {
                const localFormikId = 'recurringTransactionRules.0.transactionMetadata'
                const metadataItemKeyError = getIn(
                  formikProps.errors,
                  `recurringTransactionRules.0.transactionMetadata.${index}.key`,
                )
                const metadataItemValueError = getIn(
                  formikProps.errors,
                  `recurringTransactionRules.0.transactionMetadata.${index}.value`,
                )

                const hasCustomKeyError =
                  Object.keys(MetadataErrorsEnum).includes(metadataItemKeyError)
                const hasCustomValueError =
                  Object.keys(MetadataErrorsEnum).includes(metadataItemValueError)

                return (
                  <div
                    className="flex w-full flex-row items-center gap-3"
                    key={`metadata-item-${index}`}
                  >
                    <div className="basis-[200px]">
                      <Tooltip
                        placement="top-end"
                        title={
                          (metadataItemKeyError === MetadataErrorsEnum.uniqueness &&
                            translate('text_63fcc3218d35b9377840f5dd')) ||
                          (metadataItemKeyError === MetadataErrorsEnum.maxLength &&
                            translate('text_63fcc3218d35b9377840f5d9', { max: 20 }))
                        }
                        disableHoverListener={!hasCustomKeyError}
                      >
                        <TextInputField
                          name={`${localFormikId}.${index}.key`}
                          label={translate('text_63fcc3218d35b9377840f5a3')}
                          silentError={!hasCustomKeyError}
                          placeholder={translate('text_63fcc3218d35b9377840f5a7')}
                          formikProps={formikProps}
                          displayErrorText={false}
                        />
                      </Tooltip>
                    </div>
                    <div className="grow">
                      <Tooltip
                        placement="top-end"
                        title={
                          metadataItemValueError === MetadataErrorsEnum.maxLength
                            ? translate('text_63fcc3218d35b9377840f5e5', {
                                max: METADATA_VALUE_MAX_LENGTH_DEFAULT,
                              })
                            : undefined
                        }
                        disableHoverListener={!hasCustomValueError}
                      >
                        <TextInputField
                          name={`${localFormikId}.${index}.value`}
                          label={translate('text_63fcc3218d35b9377840f5ab')}
                          silentError={!hasCustomValueError}
                          placeholder={translate('text_63fcc3218d35b9377840f5af')}
                          formikProps={formikProps}
                          displayErrorText={false}
                        />
                      </Tooltip>
                    </div>
                    <Tooltip
                      className="flex items-center"
                      placement="top-end"
                      title={translate('text_63fcc3218d35b9377840f5e1')}
                    >
                      <Button
                        className="mt-7"
                        variant="quaternary"
                        size="medium"
                        icon="trash"
                        onClick={() => {
                          formikProps.setFieldValue(localFormikId, [
                            ...(recurringTransactionRules.transactionMetadata || []).filter(
                              (_m, j) => {
                                return j !== index
                              },
                            ),
                          ])
                        }}
                      />
                    </Tooltip>
                  </div>
                )
              })}

              <Button
                className="self-start"
                startIcon="plus"
                variant="inline"
                onClick={() => {
                  const metadatas = [
                    ...(recurringTransactionRules?.transactionMetadata || []),
                    { key: '', value: '' },
                  ]

                  formikProps.setFieldValue(
                    'recurringTransactionRules.0.transactionMetadata',
                    metadatas,
                  )
                }}
                data-test={ADD_METADATA_DATA_TEST}
              >
                {translate('text_63fcc3218d35b9377840f5bb')}
              </Button>
            </div>
          </Accordion>
        )}
      </section>
    </>
  )
}
