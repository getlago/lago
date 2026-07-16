import { array, boolean, ISchema, number, object, tuple } from 'yup'

import { CreditNoteFeeErrorEnum, FeesPerInvoice, FromFee } from '~/components/creditNote/types'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { CurrencyEnum } from '~/generated/graphql'

export const simpleFeeSchema = (maxAmount: number, currency: CurrencyEnum) =>
  object().shape({
    checked: boolean(),
    value: number()
      .default(0)
      .when('checked', ([checked], schema) => {
        return !!checked
          ? schema
              .min(0.0000000000000001, CreditNoteFeeErrorEnum.minZero)
              .max(deserializeAmount(maxAmount, currency), CreditNoteFeeErrorEnum.overMax)
              .required('')
          : schema
      }),
  })

export const generateFeesSchema = (formikInitialFees: FeesPerInvoice, currency: CurrencyEnum) =>
  object().shape(
    Object.keys(formikInitialFees || {}).reduce((accSub, subKey) => {
      const fees = formikInitialFees[subKey]?.fees || []

      accSub = {
        ...accSub,
        [subKey]: object().shape({
          fees: array().of(
            object().shape({
              checked: boolean(),
              value: number()
                .default(0)
                .when('checked', {
                  is: true,
                  then: (schema) =>
                    schema
                      .min(0.0000000000000001, CreditNoteFeeErrorEnum.minZero)
                      .test('max-amount', CreditNoteFeeErrorEnum.overMax, function (value) {
                        const fee = fees.find((f) => f.id === this.parent.id)
                        const maxAmount = deserializeAmount(fee?.maxAmount || 0, currency)

                        return value ? value <= maxAmount : true
                      })
                      .required(''),
                  otherwise: (schema) => schema,
                }),
            }),
          ),
        }),
      }
      return accSub
    }, {}),
  )

export const generateAddOnFeesSchema = (formikInitialFees: FromFee[], currency: CurrencyEnum) => {
  const validationObject: [ISchema<unknown>] = [{} as ISchema<unknown>]

  formikInitialFees.forEach((fee, i) => {
    validationObject[i] = simpleFeeSchema(fee.maxAmount, currency)
  })

  return tuple(validationObject)
}

export const generateCreditFeesSchema = (formikInitialFees: FromFee[], currency: CurrencyEnum) => {
  const validationObject: [ISchema<unknown>] = [{} as ISchema<unknown>]

  formikInitialFees.forEach((fee, i) => {
    validationObject[i] = simpleFeeSchema(fee.maxAmount, currency)
  })

  return tuple(validationObject)
}
