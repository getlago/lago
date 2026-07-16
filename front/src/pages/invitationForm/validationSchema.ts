import { z } from 'zod'

import { zodRequiredPassword } from '~/formValidation/zodCustoms'

export const invitationValidationSchema = z.object({
  password: zodRequiredPassword,
})

export type InvitationFormValues = z.infer<typeof invitationValidationSchema>

export const invitationDefaultValues: InvitationFormValues = {
  password: '',
}
