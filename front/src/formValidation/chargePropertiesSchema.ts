import { z } from 'zod'

import { AnyChargeModel } from '~/core/constants/form'
import { ChargeModelEnum } from '~/generated/graphql'

const graduatedRangeSchema = z.object({
  fromValue: z.string(),
  toValue: z.string().nullable(),
  perUnitAmount: z.string().optional(),
  flatAmount: z.string().optional(),
})

const graduatedPercentageRangeSchema = z.object({
  fromValue: z.string(),
  toValue: z.string().nullable(),
  rate: z.string().optional(),
  flatAmount: z.string().optional(),
})

const volumeRangeSchema = z.object({
  fromValue: z.string(),
  toValue: z.string().nullable(),
  perUnitAmount: z.string().optional(),
  flatAmount: z.string().optional(),
})

export const propertiesZodSchema = z.object({
  amount: z.string().optional().nullable(),
  rate: z.string().optional().nullable(),
  fixedAmount: z.string().optional().nullable(),
  freeUnits: z.string().optional().nullable(),
  freeUnitsPerEvents: z.string().optional().nullable(),
  freeUnitsPerTotalAggregation: z.string().optional().nullable(),
  packageSize: z.string().optional().nullable(),
  perTransactionMinAmount: z.string().optional().nullable(),
  perTransactionMaxAmount: z.string().optional().nullable(),
  pricingGroupKeys: z.array(z.string()).optional().nullable(),
  presentationGroupKeys: z
    .array(
      z.object({
        value: z.string().min(1, { message: 'text_1777466316764zx64sbfshro' }),
        options: z.object({
          displayInInvoice: z.enum(['true', 'false'], {
            message: 'text_1777466316764ao0o7elsjut',
          }),
        }),
      }),
    )
    .max(2)
    .optional()
    .nullable(),
  customProperties: z.unknown().optional().nullable(),
  graduatedRanges: z.array(graduatedRangeSchema).optional().nullable(),
  graduatedPercentageRanges: z.array(graduatedPercentageRangeSchema).optional().nullable(),
  volumeRanges: z.array(volumeRangeSchema).optional().nullable(),
})

export type PropertiesZodInput = z.infer<typeof propertiesZodSchema>

// Treats empty strings, undefined, null, and NaN as invalid amounts.
// This is needed because TanStack Form initializes undefined field values to ''
// and Number('') === 0 which passes isNaN checks.
function isInvalidAmount(val: string | undefined | null): boolean {
  return !val || Number.isNaN(Number(val))
}

function isInvalidRate(val: string | undefined | null): boolean {
  return Number.isNaN(Number(val)) || val === '' || val === null || val === undefined
}

// True if value is non-empty/non-undefined but not a valid number (e.g. 'a').
// Mirrors Yup's validateRangeAmounts second check.
function isNonEmptyNaN(val: string | undefined | null): boolean {
  return !!val && Number.isNaN(Number(val))
}

// For last range, toValue can be empty/null/undefined (represents infinity).
// For all other ranges, fromValue must be strictly less than toValue.
function isInvalidFromTo(fromValue: string, toValue: string | null, isLastRange: boolean): boolean {
  if (isLastRange && (toValue === undefined || toValue === null || toValue === '')) {
    return false
  }

  return Number(fromValue || 0) >= Number(toValue || 0)
}

type ValidationContext = {
  props: PropertiesZodInput
  ctx: z.RefinementCtx
  pathPrefix: string[]
}

function validateStandard({ props, ctx, pathPrefix }: ValidationContext) {
  if (isInvalidAmount(props.amount)) {
    ctx.addIssue({
      code: 'custom',
      message: 'text_624ea7c29103fd010732ab7d',
      path: [...pathPrefix, 'amount'],
    })
  }
}

function validatePackage({ props, ctx, pathPrefix }: ValidationContext) {
  if (isInvalidAmount(props.amount)) {
    ctx.addIssue({
      code: 'custom',
      message: 'text_624ea7c29103fd010732ab7d',
      path: [...pathPrefix, 'amount'],
    })
  }
  if (
    !props.packageSize ||
    Number.isNaN(Number(props.packageSize)) ||
    Number(props.packageSize) < 1
  ) {
    ctx.addIssue({
      code: 'custom',
      message: 'text_6282085b4f283b0102655888',
      path: [...pathPrefix, 'packageSize'],
    })
  }
}

function validatePercentage({ props, ctx, pathPrefix }: ValidationContext) {
  if (isInvalidRate(props.rate)) {
    ctx.addIssue({
      code: 'custom',
      message: 'text_624ea7c29103fd010732ab7d',
      path: [...pathPrefix, 'rate'],
    })
  }

  if (
    props.perTransactionMinAmount &&
    props.perTransactionMaxAmount &&
    Number(props.perTransactionMinAmount) > Number(props.perTransactionMaxAmount)
  ) {
    ctx.addIssue({
      code: 'custom',
      message: 'minAmountShouldBeLowerThanMax',
      path: [...pathPrefix, 'perTransactionMinAmount'],
    })
    ctx.addIssue({
      code: 'custom',
      message: 'maxAmountShouldBeHigherThanMin',
      path: [...pathPrefix, 'perTransactionMaxAmount'],
    })
  }
}

function validateAmountRanges(
  ranges: {
    fromValue: string
    toValue: string | null
    perUnitAmount?: string
    flatAmount?: string
  }[],
  ctx: z.RefinementCtx,
  rangePath: (string | number)[],
) {
  for (let i = 0; i < ranges.length; i++) {
    const { fromValue, toValue, perUnitAmount, flatAmount } = ranges[i]

    if (isInvalidAmount(perUnitAmount) && isInvalidAmount(flatAmount)) {
      ctx.addIssue({
        code: 'custom',
        message: 'text_624ea7c29103fd010732ab7d',
        path: [...rangePath, i, 'perUnitAmount'],
      })
      ctx.addIssue({
        code: 'custom',
        message: 'text_624ea7c29103fd010732ab7d',
        path: [...rangePath, i, 'flatAmount'],
      })
    } else {
      if (isNonEmptyNaN(perUnitAmount)) {
        ctx.addIssue({
          code: 'custom',
          message: 'text_624ea7c29103fd010732ab7d',
          path: [...rangePath, i, 'perUnitAmount'],
        })
      }
      if (isNonEmptyNaN(flatAmount)) {
        ctx.addIssue({
          code: 'custom',
          message: 'text_624ea7c29103fd010732ab7d',
          path: [...rangePath, i, 'flatAmount'],
        })
      }
    }

    if (isInvalidFromTo(fromValue, toValue, i === ranges.length - 1)) {
      ctx.addIssue({
        code: 'custom',
        message: 'text_624ea7c29103fd010732ab7d',
        path: [...rangePath, i, 'toValue'],
      })
    }
  }
}

function validateGraduated({ props, ctx, pathPrefix }: ValidationContext) {
  const ranges = props.graduatedRanges

  if (!ranges?.length) {
    ctx.addIssue({
      code: 'custom',
      message: 'text_624ea7c29103fd010732ab7d',
      path: [...pathPrefix, 'graduatedRanges'],
    })
    return
  }

  validateAmountRanges(ranges, ctx, [...pathPrefix, 'graduatedRanges'])
}

function validateGraduatedPercentage({ props, ctx, pathPrefix }: ValidationContext) {
  const ranges = props.graduatedPercentageRanges

  if (!ranges?.length) {
    ctx.addIssue({
      code: 'custom',
      message: 'text_624ea7c29103fd010732ab7d',
      path: [...pathPrefix, 'graduatedPercentageRanges'],
    })
    return
  }

  for (let i = 0; i < ranges.length; i++) {
    const { fromValue, toValue, rate } = ranges[i]

    if (isInvalidRate(rate)) {
      ctx.addIssue({
        code: 'custom',
        message: 'text_624ea7c29103fd010732ab7d',
        path: [...pathPrefix, 'graduatedPercentageRanges', i, 'rate'],
      })
    }

    if (isInvalidFromTo(fromValue, toValue, i === ranges.length - 1)) {
      ctx.addIssue({
        code: 'custom',
        message: 'text_624ea7c29103fd010732ab7d',
        path: [...pathPrefix, 'graduatedPercentageRanges', i, 'toValue'],
      })
    }
  }
}

function validateVolume({ props, ctx, pathPrefix }: ValidationContext) {
  const ranges = props.volumeRanges

  if (!ranges?.length) {
    ctx.addIssue({
      code: 'custom',
      message: 'text_624ea7c29103fd010732ab7d',
      path: [...pathPrefix, 'volumeRanges'],
    })
    return
  }

  validateAmountRanges(ranges, ctx, [...pathPrefix, 'volumeRanges'])
}

function validateCustom({ props, ctx, pathPrefix }: ValidationContext) {
  if (!props.customProperties) {
    ctx.addIssue({
      code: 'custom',
      message: 'text_624ea7c29103fd010732ab7d',
      path: [...pathPrefix, 'customProperties'],
    })
    return
  }

  try {
    const parsed =
      typeof props.customProperties === 'string'
        ? JSON.parse(props.customProperties)
        : props.customProperties

    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
      throw new Error('Invalid custom properties: must be a non-null object')
    }
  } catch {
    ctx.addIssue({
      code: 'custom',
      message: 'text_624ea7c29103fd010732ab7d',
      path: [...pathPrefix, 'customProperties'],
    })
  }
}

const validators: Partial<Record<ChargeModelEnum, (context: ValidationContext) => void>> = {
  [ChargeModelEnum.Standard]: validateStandard,
  [ChargeModelEnum.Package]: validatePackage,
  [ChargeModelEnum.Percentage]: validatePercentage,
  [ChargeModelEnum.Graduated]: validateGraduated,
  [ChargeModelEnum.GraduatedPercentage]: validateGraduatedPercentage,
  [ChargeModelEnum.Volume]: validateVolume,
  [ChargeModelEnum.Custom]: validateCustom,
}

// Returns the set of indices that are part of a duplicate (case-sensitive,
// trimmed) value group. Empty rows are skipped — they get the "value is
// required" error instead of a misleading duplicate error.
function findDuplicatePresentationGroupKeyIndices(
  presentationGroupKeys: NonNullable<PropertiesZodInput['presentationGroupKeys']>,
): Set<number> {
  const seen = new Map<string, number>()
  const duplicateIndices = new Set<number>()

  presentationGroupKeys.forEach((group, i) => {
    const v = (group.value ?? '').trim()

    if (!v) return

    const firstIndex = seen.get(v)

    if (firstIndex !== undefined) {
      // Mark BOTH the first occurrence and the current one — the user should
      // be able to fix either side, so highlighting both rows reads better
      // than silently blaming the second.
      duplicateIndices.add(firstIndex)
      duplicateIndices.add(i)
    } else {
      seen.set(v, i)
    }
  })

  return duplicateIndices
}

// Validate presentationGroupKeys for all charge models.
function validatePresentationGroupKeys(
  presentationGroupKeys: NonNullable<PropertiesZodInput['presentationGroupKeys']>,
  ctx: z.RefinementCtx,
  pathPrefix: string[],
) {
  const duplicateIndices = findDuplicatePresentationGroupKeyIndices(presentationGroupKeys)

  presentationGroupKeys.forEach((group, i) => {
    if (!group.value) {
      ctx.addIssue({
        code: 'custom',
        message: 'text_1777466316764zx64sbfshro',
        path: [...pathPrefix, 'presentationGroupKeys', String(i), 'value'],
      })
    } else if (duplicateIndices.has(i)) {
      ctx.addIssue({
        code: 'custom',
        message: 'text_17791906642738j2tip131uw',
        path: [...pathPrefix, 'presentationGroupKeys', String(i), 'value'],
      })
    }

    if (group.options?.displayInInvoice !== 'true' && group.options?.displayInInvoice !== 'false') {
      ctx.addIssue({
        code: 'custom',
        message: 'text_1777466316764ao0o7elsjut',
        path: [...pathPrefix, 'presentationGroupKeys', String(i), 'options', 'displayInInvoice'],
      })
    }
  })
}

export function validateChargeProperties(
  chargeModel: AnyChargeModel,
  props: PropertiesZodInput | undefined,
  ctx: z.RefinementCtx,
  pathPrefix: string[],
) {
  if (!props) return

  validators[chargeModel as ChargeModelEnum]?.({ props, ctx, pathPrefix })

  if (props.presentationGroupKeys) {
    validatePresentationGroupKeys(props.presentationGroupKeys, ctx, pathPrefix)
  }
}
