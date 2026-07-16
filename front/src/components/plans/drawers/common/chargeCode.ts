import { AnyFormApi } from '@tanstack/react-form'
import { z } from 'zod'

import { generateUniqueCode } from '~/core/utils/generateUniqueCode'

// Backend "code already exists" message, surfaced under the Code input on save
// and cleared when the user edits the code (so submit re-enables). Shared by the
// fixed- and usage-charge drawers so the string can't drift between them.
export const EXISTING_CODE_ERROR_MESSAGE = 'text_632a2d437e341dcc76817556'

const CODE_REQUIRED_MESSAGE = 'text_624ea7c29103fd010732ab7d'

// `code` is only required when the field is shown (v2 details/edition via
// `showCode`); the legacy plan form keeps it optional so its hidden, empty code
// never blocks submit.
export const buildChargeCodeSchema = (requireCode: boolean) =>
  requireCode ? z.string().min(1, { message: CODE_REQUIRED_MESSAGE }) : z.string()

// Surfaces the backend duplicate-code rejection under the Code input (keeps the
// drawer open). Same pattern as plan-settings code.
export const applyExistingCodeError = (formApi: AnyFormApi): void => {
  formApi.setFieldMeta('code', (meta) => ({
    ...meta,
    errorMap: { ...meta.errorMap, onDynamic: { message: EXISTING_CODE_ERROR_MESSAGE } },
  }))
}

// Seeds a unique charge code from a source (add-on / billable-metric) code when
// the Code field is shown in create mode; backend still enforces final
// uniqueness. No-op when disabled so callers can pass the guard inline.
export const seedChargeCode = ({
  enabled,
  sourceCode,
  existingChargeCodes,
  setCode,
}: {
  enabled: boolean
  sourceCode: string
  existingChargeCodes: (string | null | undefined)[] | undefined
  setCode: (code: string) => void
}): void => {
  if (!enabled) return

  setCode(generateUniqueCode(sourceCode, existingChargeCodes ?? []))
}
