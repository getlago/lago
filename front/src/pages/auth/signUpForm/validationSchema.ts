import { z } from 'zod'

import { zodRequiredEmail, zodRequiredPassword } from '~/formValidation/zodCustoms'

export const signUpValidationSchema = z.object({
  organizationName: z.string().min(1, { message: 'text_620bc4d4269a55014d493f4d' }),
  email: zodRequiredEmail,
  password: zodRequiredPassword,
})

// Google register only requires organization name, but has same shape as signUpValidationSchema
export const googleRegisterValidationSchema = z.object({
  organizationName: z.string().min(1, {
    message: 'text_620bc4d4269a55014d493f4d',
  }),
  email: z.string(),
  password: z.string(),
})

export type SignUpFormValues = z.infer<typeof signUpValidationSchema>

export const signUpDefaultValues: SignUpFormValues = {
  organizationName: '',
  email: '',
  password: '',
}
