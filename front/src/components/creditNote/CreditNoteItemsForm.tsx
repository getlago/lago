import { FormikProps } from 'formik'
import _get from 'lodash/get'
import { FC, useMemo } from 'react'

import { CreditNoteFormItem } from '~/components/creditNote/CreditNoteFormItem'
import { CreditNoteForm, FeesPerInvoice, FromFee } from '~/components/creditNote/types'
import { Typography } from '~/components/designSystem/Typography'
import { Checkbox } from '~/components/form/Checkbox'
import { intlFormatDateTime } from '~/core/timezone'
import { CurrencyEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

export const getSubscriptionCheckboxTestId = (subscriptionKey: string) =>
  `subscription-checkbox-${subscriptionKey}`

const determineCheckboxValue = (
  initialValue: boolean | undefined | null,
  additionalValue: boolean | undefined,
) => {
  if (initialValue === undefined || additionalValue === undefined) return undefined
  if (initialValue === null) {
    return additionalValue
  }
  if (initialValue !== additionalValue) {
    return undefined
  }
  return additionalValue
}

interface CreditNoteItemsFormProps {
  isPrepaidCreditsInvoice: boolean
  formikProps: FormikProps<Partial<CreditNoteForm>>
  feeForCredit?: FromFee[]
  feeForAddOn?: FromFee[]
  feesPerInvoice?: FeesPerInvoice
  currency: CurrencyEnum
}

export const CreditNoteItemsForm: FC<CreditNoteItemsFormProps> = ({
  isPrepaidCreditsInvoice,
  formikProps,
  feeForCredit,
  feeForAddOn,
  feesPerInvoice,
  currency,
}) => {
  const { translate } = useInternationalization()

  const checkboxGroupValue = useMemo(() => {
    const fees = formikProps.values.fees || {}

    return Object.keys(fees).reduce((acc, subscriptionKey) => {
      const subscriptionValues = fees[subscriptionKey]
      let subscriptionGroupValue: boolean | undefined | null = null

      subscriptionValues.fees?.forEach((fee) => {
        subscriptionGroupValue = determineCheckboxValue(subscriptionGroupValue, fee?.checked)
      })

      return { ...acc, [subscriptionKey]: { value: subscriptionGroupValue } }
    }, {})
  }, [formikProps.values.fees])

  return (
    <div>
      {isPrepaidCreditsInvoice && (
        <div className="flex h-12 flex-row items-center justify-between shadow-b">
          <Checkbox
            label={
              <Typography variant="bodyHl" color="grey500">
                {translate('text_661ff6e56ef7e1b7c542b200')}
              </Typography>
            }
            value={formikProps.values.creditFee?.[0]?.checked}
            onChange={(_, value) => {
              formikProps.setFieldValue(`creditFee.0.checked`, value)
            }}
          />

          <Typography variant="bodyHl" color="grey500">
            {translate('text_636bedf292786b19d3398ee0')}
          </Typography>
        </div>
      )}

      {feeForCredit &&
        feeForCredit.map((fee, i) => (
          <CreditNoteFormItem
            key={fee?.id}
            formikProps={formikProps}
            currency={currency}
            feeName={translate('text_1729262241097k3cnpci6p5j')}
            formikKey={`creditFee.${i}`}
            maxValue={fee?.maxAmount}
            isReadOnly={fee?.isReadOnly}
          />
        ))}

      {feeForAddOn &&
        feeForAddOn.map((fee, i) => (
          <CreditNoteFormItem
            key={fee?.id}
            formikProps={formikProps}
            currency={currency}
            feeName={fee?.name}
            formikKey={`addOnFee.${i}`}
            maxValue={fee?.maxAmount}
            isReadOnly={fee?.isReadOnly}
          />
        ))}

      {feesPerInvoice &&
        Object.keys(feesPerInvoice).map((subKey) => {
          const subscription = feesPerInvoice[subKey]

          return (
            <div key={subKey}>
              <div className="flex h-12 flex-row items-center justify-between shadow-b">
                <Checkbox
                  canBeIndeterminate
                  value={_get(checkboxGroupValue, `${subKey}.value`)}
                  label={
                    <Typography variant="bodyHl" color="grey500">
                      {subscription?.subscriptionName}
                    </Typography>
                  }
                  data-test={getSubscriptionCheckboxTestId(subKey)}
                  onChange={(_, value) => {
                    const fees = formikProps.values.fees?.[subKey]?.fees || []

                    formikProps.setFieldValue(
                      `fees.${subKey}.fees`,
                      fees.map((fee) => ({ ...fee, checked: value })),
                    )
                  }}
                />
                <Typography variant="bodyHl" color="grey500">
                  {translate('text_636bedf292786b19d3398ee0')}
                </Typography>
              </div>
              {subscription?.fees?.map((fee, feeIndex) => (
                <CreditNoteFormItem
                  key={fee?.id}
                  formikProps={formikProps}
                  currency={currency}
                  feeName={`${fee?.name}${
                    fee.isTrueUpFee ? ` - ${translate('text_64463aaa34904c00a23be4f7')}` : ''
                  }`}
                  formikKey={`fees.${subKey}.fees.${feeIndex}`}
                  maxValue={fee?.maxAmount || 0}
                  feeSucceededAt={
                    !!fee?.succeededAt ? intlFormatDateTime(fee?.succeededAt).date : undefined
                  }
                  isReadOnly={fee?.isReadOnly}
                />
              ))}
            </div>
          )
        })}
    </div>
  )
}
