import { addMethod, string } from 'yup'

import { validateHostWithoutProtocol } from '~/core/utils/validateHostWithoutProtocol'

const EMAIL_REGEX: RegExp =
  // eslint-disable-next-line no-control-regex
  /^(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])$/i

const DOMAIN_REGEX: RegExp =
  /^((?!-))(xn--)?[a-z0-9][a-z0-9-_]{0,61}[a-z0-9]{0,1}\.(xn--)?([a-z0-9-]{1,61}|[a-z0-9-]{1,30}\.[a-z]{2,})$/

export const initializeYup = () => {
  addMethod(string, 'email', function validateEmail(message) {
    return this.matches(EMAIL_REGEX, {
      message,
      name: 'email',
      excludeEmptyString: true,
    })
  })

  addMethod(string, 'emails', function validateEmails(message) {
    return this.test('emails', message, function (value) {
      if (!value?.trim()) return true

      const { path, createError } = this
      const emails = value.split(',').map((email) => email.trim())
      const areEmailsValid = emails.every((email) => EMAIL_REGEX.test(email))

      return areEmailsValid || createError({ path, message })
    })
  })

  addMethod(string, 'domain', function validateDomain(message) {
    return this.matches(DOMAIN_REGEX, {
      message,
      name: 'string.domain',
      excludeEmptyString: true,
    })
  })

  addMethod(string, 'host', function validateHost(message) {
    return this.test('host', message, function (value) {
      if (!value?.trim()) return true

      return validateHostWithoutProtocol(value)
    })
  })
}
