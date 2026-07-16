import { array, number, object, string } from 'yup'

import { LocalChargeFilterInput, LocalPricingUnitType } from '~/components/plans/types'
import { MIN_AMOUNT_SHOULD_BE_LOWER_THAN_MAX_ERROR } from '~/core/constants/form'
import {
  BillableMetric,
  ChargeModelEnum,
  GraduatedPercentageRangeInput,
  GraduatedRangeInput,
  Properties,
  VolumeRangeInput,
} from '~/generated/graphql'

// Helper function to validate fromValue is less than toValue
const validateFromToValues = (
  fromValue: string | number | null | undefined,
  toValue: string | number | null | undefined,
  isLastRange: boolean,
): boolean => {
  // For the last range, toValue can be empty/undefined (meaning infinity)
  if (isLastRange && (toValue === undefined || toValue === null || toValue === '')) {
    return true
  }

  return Number(fromValue || 0) < Number(toValue || 0)
}

// Helper function to validate perUnitAmount and flatAmount
const validateRangeAmounts = (perUnitAmount: string, flatAmount: string): boolean => {
  // Check if both perUnitAmount and flatAmount are invalid
  if (isNaN(Number(perUnitAmount)) && isNaN(Number(flatAmount))) {
    return false
  }

  // Check if either perUnitAmount or flatAmount is invalid (but not empty/undefined)
  if (
    (perUnitAmount !== undefined && perUnitAmount !== '' && isNaN(Number(perUnitAmount))) ||
    (flatAmount !== undefined && flatAmount !== '' && isNaN(Number(flatAmount)))
  ) {
    return false
  }

  return true
}

// Helper function to validate rate field
const validateRate = (rate: string | number | null | undefined): boolean => {
  return !(isNaN(Number(rate)) || rate === '' || rate === null)
}

// Helper function to create chargeModel conditional check
const isChargeModel = (chargeModel: ChargeModelEnum, targetModel: ChargeModelEnum): boolean => {
  return !!chargeModel && chargeModel === targetModel
}

// Helper function to check if billableMetric has filters
const hasFilters = (billableMetric: BillableMetric): boolean => {
  return !!billableMetric && !!billableMetric.filters?.length
}

// Helper function to create filter shape
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const createFilterShape = (propertiesShape: any) => {
  return object().shape({
    invoiceDisplayName: string().nullable(),
    properties: object().shape(propertiesShape),
    values: array().min(1).required(''),
  })
}

const standardShape = {
  amount: number().typeError('text_624ea7c29103fd010732ab7d').required(''),
}

const packageShape = {
  amount: number().typeError('text_624ea7c29103fd010732ab7d').required(''),
  packageSize: number()
    .min(1, 'text_6282085b4f283b0102655888')
    .required('text_6282085b4f283b0102655888'),
}

const percentageShape = {
  rate: number().required(''),
  fixedAmount: number(),
  freeUnitsPerEvents: number(),
  freeUnitsPerTotalAggregation: number(),
  perTransactionMinAmount: number().test(
    MIN_AMOUNT_SHOULD_BE_LOWER_THAN_MAX_ERROR,
    MIN_AMOUNT_SHOULD_BE_LOWER_THAN_MAX_ERROR,
    (value, ctx) =>
      !value || !ctx.parent.perTransactionMaxAmount || value <= ctx.parent.perTransactionMaxAmount,
  ),
  perTransactionMaxAmount: number(),
}

const graduatedShape = {
  graduatedRanges: array()
    .test({
      test: (graduatedRanges: GraduatedRangeInput[] | undefined) => {
        let isValid = true

        graduatedRanges?.every(({ fromValue, toValue, perUnitAmount, flatAmount }, i) => {
          // Validate perUnitAmount and flatAmount
          if (!validateRangeAmounts(perUnitAmount, flatAmount)) {
            isValid = false
            return false
          }

          // Validate fromValue < toValue
          const isLastRange = i === graduatedRanges.length - 1

          if (!validateFromToValues(fromValue, toValue, isLastRange)) {
            isValid = false
            return false
          }

          return true
        })

        return isValid
      },
    })
    .min(1)
    .required(''),
}

const graduatedPercentageShape = {
  graduatedPercentageRanges: array()
    .test({
      test: (graduatedPercentageRanges: GraduatedPercentageRangeInput[] | undefined) => {
        let isValid = true

        graduatedPercentageRanges?.every(({ fromValue, toValue, rate }, i) => {
          // Validate rate
          if (!validateRate(rate)) {
            isValid = false
            return false
          }

          // Validate fromValue < toValue
          const isLastRange = i === graduatedPercentageRanges.length - 1

          if (!validateFromToValues(fromValue, toValue, isLastRange)) {
            isValid = false
            return false
          }

          return true
        })

        return isValid
      },
    })
    .min(1)
    .required(''),
}

const volumeShape = {
  volumeRanges: array()
    .test({
      test: (volumeRanges: VolumeRangeInput[] | undefined) => {
        let isValid = true

        volumeRanges?.every(({ fromValue, toValue, perUnitAmount, flatAmount }, i) => {
          // Validate perUnitAmount and flatAmount
          if (!validateRangeAmounts(perUnitAmount, flatAmount)) {
            isValid = false
            return false
          }

          // Validate fromValue < toValue
          const isLastRange = i === volumeRanges.length - 1

          if (!validateFromToValues(fromValue, toValue, isLastRange)) {
            isValid = false
            return false
          }

          return true
        })

        return isValid
      },
    })
    .min(1)
    .required(''),
}

const propertiesShape = object()
  .when('chargeModel', {
    is: (chargeModel: ChargeModelEnum) => isChargeModel(chargeModel, ChargeModelEnum.Standard),
    then: () =>
      object().when({
        is: (values: Properties) => !!values,
        then: (schema) => schema.shape(standardShape),
      }),
  })
  .when('chargeModel', {
    is: (chargeModel: ChargeModelEnum) => isChargeModel(chargeModel, ChargeModelEnum.Package),
    then: () =>
      object().when({
        is: (values: Properties) => !!values,
        then: (schema) => schema.shape(packageShape),
      }),
  })
  .when('chargeModel', {
    is: (chargeModel: ChargeModelEnum) => isChargeModel(chargeModel, ChargeModelEnum.Percentage),
    then: () =>
      object().when({
        is: (values: Properties) => !!values,
        then: (schema) => schema.shape(percentageShape),
      }),
  })
  .when('chargeModel', {
    is: (chargeModel: ChargeModelEnum) => isChargeModel(chargeModel, ChargeModelEnum.Graduated),
    then: () =>
      object().when({
        is: (values: Properties) => !!values,
        then: (schema) => schema.shape(graduatedShape),
      }),
  })
  .when('chargeModel', {
    is: (chargeModel: ChargeModelEnum) =>
      isChargeModel(chargeModel, ChargeModelEnum.GraduatedPercentage),
    then: () =>
      object().when({
        is: (values: Properties) => !!values,
        then: (schema) => schema.shape(graduatedPercentageShape),
      }),
  })
  .when('chargeModel', {
    is: (chargeModel: ChargeModelEnum) => isChargeModel(chargeModel, ChargeModelEnum.Volume),
    then: () =>
      object().when({
        is: (values: Properties) => !!values,
        then: (schema) => schema.shape(volumeShape),
      }),
  })
  .when('chargeModel', {
    is: (chargeModel: ChargeModelEnum) => isChargeModel(chargeModel, ChargeModelEnum.Custom),
    then: (schema) => schema.shape(customShape),
  })

const filtersShape = array()
  .when(['chargeModel', 'billableMetric'], {
    is: (chargeModel: ChargeModelEnum, billableMetric: BillableMetric) =>
      isChargeModel(chargeModel, ChargeModelEnum.Standard) && hasFilters(billableMetric),
    then: (schema) => schema.of(createFilterShape(standardShape)),
  })
  .when(['chargeModel', 'billableMetric'], {
    is: (chargeModel: ChargeModelEnum, billableMetric: BillableMetric) =>
      isChargeModel(chargeModel, ChargeModelEnum.Package) && hasFilters(billableMetric),
    then: (schema) => schema.of(createFilterShape(packageShape)),
  })
  .when(['chargeModel', 'billableMetric'], {
    is: (chargeModel: ChargeModelEnum, billableMetric: BillableMetric) =>
      isChargeModel(chargeModel, ChargeModelEnum.Percentage) && hasFilters(billableMetric),
    then: (schema) => schema.of(createFilterShape(percentageShape)),
  })
  .when(['chargeModel', 'billableMetric'], {
    is: (chargeModel: ChargeModelEnum, billableMetric: BillableMetric) =>
      isChargeModel(chargeModel, ChargeModelEnum.Graduated) && hasFilters(billableMetric),
    then: (schema) => schema.of(createFilterShape(graduatedShape)),
  })
  .when(['chargeModel', 'billableMetric'], {
    is: (chargeModel: ChargeModelEnum, billableMetric: BillableMetric) =>
      isChargeModel(chargeModel, ChargeModelEnum.GraduatedPercentage) && hasFilters(billableMetric),
    then: (schema) => schema.of(createFilterShape(graduatedPercentageShape)),
  })
  .when(['chargeModel', 'billableMetric'], {
    is: (chargeModel: ChargeModelEnum, billableMetric: BillableMetric) =>
      isChargeModel(chargeModel, ChargeModelEnum.Volume) && hasFilters(billableMetric),
    then: (schema) => schema.of(createFilterShape(volumeShape)),
  })

const customShape = {
  customProperties: object().json().required(''),
}

export const chargeSchema = array().of(
  object().shape({
    chargeModel: string().required(''),
    appliedPricingUnit: object()
      .shape({
        type: string().required(''),
        code: string().required(''),
        shortName: string().required(''),
        conversionRate: string().when('type', {
          is: LocalPricingUnitType.Custom,
          then: (schema) =>
            schema.required('').test('conversionRate', '', (value) => Number(value || 0) > 0),
          otherwise: (schema) => schema.optional(),
        }),
      })
      .default(undefined)
      .nullable()
      .notRequired(),
    properties: propertiesShape.when(['filters'], {
      is: (filter: LocalChargeFilterInput[]) => !filter?.length,
      then: (schema) => schema.required(),
      otherwise: (schema) => schema.optional(),
    }),
    filters: filtersShape,
  }),
)

export const fixedChargeSchema = array().of(
  object().shape({
    chargeModel: string().required(''),
    properties: propertiesShape,
    units: string()
      .test({
        test: (value) => !isNaN(Number(value || 0)),
        message: 'text_624ea7c29103fd010732ab7d',
      })
      .required(''),
  }),
)
