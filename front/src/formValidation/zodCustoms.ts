import { z } from 'zod'

import { validateHostWithoutProtocol } from '~/core/utils/validateHostWithoutProtocol'
import { allPermissions } from '~/pages/settings/teamAndSecurity/roles/common/permissionsConst'
import { PermissionName } from '~/pages/settings/teamAndSecurity/roles/common/permissionsTypes'

export const EMAIL_REGEX: RegExp =
  // eslint-disable-next-line no-control-regex
  /^(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])$/i

const DOMAIN_REGEX: RegExp =
  /^((?!-))(xn--)?[a-z0-9][a-z0-9-_]{0,61}[a-z0-9]{0,1}\.(xn--)?([a-z0-9-]{1,61}|[a-z0-9-]{1,30}\.[a-z]{2,})$/

export const zodMultipleEmails = z.string().refine((val) => {
  if (!val) return true
  if (typeof val !== 'string') return false
  const separatedEmails = val.split(',').map((mail) => mail.trim())

  try {
    z.array(z.string().regex(EMAIL_REGEX)).parse(separatedEmails)
  } catch {
    return false
  }

  return true
}, 'text_620bc4d4269a55014d493fc3')

export const zodDomain = z.string().refine((val) => {
  if (typeof val !== 'string') return false

  return DOMAIN_REGEX.test(val)
}, 'text_664c732c264d7eed1c74fe03')

export const zodHost = z.string().refine((val) => {
  if (typeof val !== 'string') return false

  return validateHostWithoutProtocol(val)
}, 'text_664c732c264d7eed1c74fdd3')

export const zodOptionalHost = z.string().refine((val) => {
  if (typeof val !== 'string') return false
  if (!val.length) return true

  return validateHostWithoutProtocol(val)
}, 'text_664c732c264d7eed1c74fdd3')

export const zodOptionalUrl = z.string().refine((value) => {
  if (!value) return true

  try {
    z.url().parse(value)
  } catch {
    return false
  }

  return true
}, 'text_1764239804026ca61hwr3pp9')

export const zodOneOfPermissions = z.string().refine((value) => {
  if (typeof value !== 'string') return false

  return allPermissions.includes(value as PermissionName)
})

export const zodRequiredEmail = z
  .string()
  .min(1, { message: 'text_620bc4d4269a55014d493f3d' })
  .refine((val) => EMAIL_REGEX.test(val), 'text_620bc4d4269a55014d493fc3')

// Password validation error messages
export const PASSWORD_VALIDATION_ERRORS = {
  REQUIRED: 'text_620bc4d4269a55014d493f61',
  MIN: 'text_620bc4d4269a55014d493fac',
  LOWERCASE: 'text_620bc4d4269a55014d493f57',
  UPPERCASE: 'text_620bc4d4269a55014d493f7b',
  NUMBER: 'text_620bc4d4269a55014d493f8d',
  SPECIAL: 'text_620bc4d4269a55014d493fa0',
} as const

/** Stable data-test ids for password validation rules (used mainly by e2e). */
export const PASSWORD_VALIDATION_TEST_IDS: Record<
  (typeof PASSWORD_VALIDATION_ERRORS)[keyof Omit<typeof PASSWORD_VALIDATION_ERRORS, 'REQUIRED'>],
  string
> = {
  [PASSWORD_VALIDATION_ERRORS.MIN]: 'MIN',
  [PASSWORD_VALIDATION_ERRORS.LOWERCASE]: 'LOWERCASE',
  [PASSWORD_VALIDATION_ERRORS.UPPERCASE]: 'UPPERCASE',
  [PASSWORD_VALIDATION_ERRORS.NUMBER]: 'NUMBER',
  [PASSWORD_VALIDATION_ERRORS.SPECIAL]: 'SPECIAL',
}

const SPECIAL_CHARS_REGEX = /[/_!@#$%^&*(),.?":{}|<>-]/

// Single source of truth for password validation
export const validatePassword = (password: string): string[] => {
  const errors: string[] = []

  if (password.length < 8) {
    errors.push(PASSWORD_VALIDATION_ERRORS.MIN)
  }
  if (!/[a-z]/.test(password)) {
    errors.push(PASSWORD_VALIDATION_ERRORS.LOWERCASE)
  }
  if (!/[A-Z]/.test(password)) {
    errors.push(PASSWORD_VALIDATION_ERRORS.UPPERCASE)
  }
  if (!/\d/.test(password)) {
    errors.push(PASSWORD_VALIDATION_ERRORS.NUMBER)
  }
  if (!SPECIAL_CHARS_REGEX.test(password)) {
    errors.push(PASSWORD_VALIDATION_ERRORS.SPECIAL)
  }

  return errors
}

export const zodRequiredPassword = z
  .string()
  .min(1, { message: PASSWORD_VALIDATION_ERRORS.REQUIRED })
  .superRefine((val, ctx) => {
    validatePassword(val).forEach((error) => {
      ctx.addIssue({
        code: 'custom',
        message: error,
      })
    })
  })
