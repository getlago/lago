import { useMemo } from 'react'

import { validatePassword } from '~/formValidation/zodCustoms'

type PasswordValidationResult = {
  isValid: boolean
  errors: string[]
}

export const usePasswordValidation = (password: string): PasswordValidationResult => {
  return useMemo(() => {
    const errors = validatePassword(password)

    return {
      isValid: errors.length === 0,
      errors,
    }
  }, [password])
}
