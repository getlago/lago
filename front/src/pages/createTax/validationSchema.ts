import { z } from 'zod'

export const taxFormSchema = z.object({
  code: z.string().min(1, ''),
  description: z.string().optional(),
  name: z.string().min(1, ''),
  rate: z
    .string()
    .min(1, '')
    .refine((val) => {
      const num = Number(val)

      return !isNaN(num) && num <= 100
    }, 'text_645bb193927b375079d28b88'),
})

export type TaxFormValues = z.infer<typeof taxFormSchema>

export const emptyTaxDefaultValues: TaxFormValues = {
  code: '',
  description: '',
  name: '',
  rate: '',
}
