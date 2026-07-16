import { array, object, string } from 'yup'
import { z } from 'zod'

export const METADATA_VALUE_MAX_LENGTH_DEFAULT = 100
export const METADATA_KEY_MAX_LENGTH = 20

export enum MetadataErrorsEnum {
  uniqueness = 'uniqueness',
  maxLength = 'maxLength',
  required = 'required',
}

export const metadataSchema = ({
  valueMaxLength = METADATA_VALUE_MAX_LENGTH_DEFAULT,
  metadataKey = 'metadata',
  keyMaxLength = METADATA_KEY_MAX_LENGTH,
} = {}) =>
  array().of(
    object().shape({
      key: string().test({
        test: function (value, { createError, path, from }) {
          if (!value) {
            return false
          }

          if (from?.[1]?.value?.[metadataKey]?.length > 1) {
            const keysList = from?.[1]?.value?.[metadataKey]?.map((m: { key: string }) => m.key)

            // Check key unicity
            if (keysList?.indexOf(value) !== keysList?.lastIndexOf(value)) {
              return createError({
                path,
                message: MetadataErrorsEnum.uniqueness,
              })
            }
          }

          if (value.length > keyMaxLength) {
            return createError({
              path,
              message: MetadataErrorsEnum.maxLength,
            })
          }

          return true
        },
      }),
      value: string().test({
        test: (value, { createError, path }) => {
          if (!value) return false
          if (value.length > valueMaxLength) {
            return createError({
              path,
              message: MetadataErrorsEnum.maxLength,
            })
          }

          return true
        },
      }),
    }),
  )

export const zodMetadataSchema = (valueMaxLength = METADATA_VALUE_MAX_LENGTH_DEFAULT) =>
  z
    .array(
      z.object({
        key: z
          .string()
          .refine((value) => !!value, MetadataErrorsEnum.required)
          .refine((value) => value.length <= METADATA_KEY_MAX_LENGTH, MetadataErrorsEnum.maxLength),
        value: z
          .string()
          .refine((value) => !!value, MetadataErrorsEnum.required)
          .refine((value) => value.length <= valueMaxLength, MetadataErrorsEnum.maxLength),
        displayInInvoice: z.boolean().optional(),
        id: z.string().optional(),
      }),
    )
    .superRefine((items, ctx) => {
      const seen = new Map<string, number>()
      const errorAdded = new Set<number>()

      // check uniqueness on keys
      items.forEach((item, idx) => {
        if (seen.has(item.key)) {
          ctx.addIssue({
            code: 'custom',
            message: MetadataErrorsEnum.uniqueness,
            path: [idx, 'key'],
          })
          errorAdded.add(idx)

          const firstIdx = seen.get(item.key)

          if (firstIdx !== undefined && !errorAdded.has(firstIdx)) {
            ctx.addIssue({
              code: 'custom',
              message: MetadataErrorsEnum.uniqueness,
              path: [firstIdx, 'key'],
            })
            errorAdded.add(firstIdx)
          }
        } else {
          seen.set(item.key, idx)
        }
      })
    })
