import { z } from 'zod'

import { zodRequiredEmail } from '~/formValidation/zodCustoms'

export const forgotPasswordValidationSchema = z.object({
  email: zodRequiredEmail,
})

export type ForgotPasswordFormValues = z.infer<typeof forgotPasswordValidationSchema>

export const forgotPasswordDefaultValues: ForgotPasswordFormValues = {
  email: '',
}
