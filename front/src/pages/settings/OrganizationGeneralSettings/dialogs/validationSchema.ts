import { z } from 'zod'

const SLUG_FORMAT_REGEX = /^[a-z0-9]([a-z0-9-]*[a-z0-9])?$/
const SLUG_MIN_LENGTH = 3
const SLUG_MAX_LENGTH = 40

export const editOrganizationSlugValidationSchema = z.object({
  slug: z.string().superRefine((value, ctx) => {
    if (
      value.length < SLUG_MIN_LENGTH ||
      value.length > SLUG_MAX_LENGTH ||
      !SLUG_FORMAT_REGEX.test(value)
    ) {
      ctx.addIssue({
        code: 'custom',
        message: 'text_1776867582730967zpytg618',
      })
    }
  }),
})

export type EditOrganizationSlugFormValues = z.infer<typeof editOrganizationSlugValidationSchema>

export const editOrganizationSlugDefaultValues: EditOrganizationSlugFormValues = {
  slug: '',
}
