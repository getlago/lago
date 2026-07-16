import { z } from 'zod'

import { zodRequiredEmail } from '~/formValidation/zodCustoms'

export const loginOktaValidationSchema = z.object({
  email: zodRequiredEmail,
})

export type LoginOktaFormValues = z.infer<typeof loginOktaValidationSchema>

export const loginOktaDefaultValues: LoginOktaFormValues = {
  email: '',
}
