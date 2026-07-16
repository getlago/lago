import { z } from 'zod'

import { WebhookEndpointSignatureAlgoEnum } from '~/generated/graphql'

export const webhookValidationSchema = z.object({
  name: z.string(),
  webhookUrl: z.string().min(1, { message: 'text_6271200984178801ba8bdf58' }),
  signatureAlgo: z.nativeEnum(WebhookEndpointSignatureAlgoEnum),
  webhookEvents: z.record(z.string(), z.boolean()),
})

export type WebhookFormValues = z.infer<typeof webhookValidationSchema>

export const webhookDefaultValues: WebhookFormValues = {
  name: '',
  webhookUrl: '',
  signatureAlgo: WebhookEndpointSignatureAlgoEnum.Hmac,
  webhookEvents: {},
}
