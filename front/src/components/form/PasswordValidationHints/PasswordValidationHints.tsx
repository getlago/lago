import { Alert } from '~/components/designSystem/Alert'
import { Typography } from '~/components/designSystem/Typography'
import {
  PASSWORD_VALIDATION_ERRORS,
  PASSWORD_VALIDATION_TEST_IDS,
} from '~/formValidation/zodCustoms'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { theme } from '~/styles'
import { tw } from '~/styles/utils'

// Validation keys shown in the UI feedback (excludes REQUIRED)
export const PASSWORD_VALIDATION_KEYS = [
  PASSWORD_VALIDATION_ERRORS.MIN,
  PASSWORD_VALIDATION_ERRORS.LOWERCASE,
  PASSWORD_VALIDATION_ERRORS.UPPERCASE,
  PASSWORD_VALIDATION_ERRORS.NUMBER,
  PASSWORD_VALIDATION_ERRORS.SPECIAL,
] as const

// Static test IDs for e2e testing
export const PASSWORD_HINTS_TEST_IDS = {
  VISIBLE: 'password-validation--visible',
  HIDDEN: 'password-validation--hidden',
  SUCCESS: 'password-validation--success',
} as const

export type PasswordValidationHintsProps = {
  password: string
  errors: string[]
  isValid: boolean
  successMessage?: string
  className?: string
}

export const PasswordValidationHints = ({
  password,
  errors,
  isValid,
  successMessage = 'text_620bc4d4269a55014d493fbe',
  className,
}: PasswordValidationHintsProps) => {
  const { translate } = useInternationalization()

  if (isValid) {
    return (
      <Alert
        className={tw('mt-4', className)}
        type="success"
        data-test={PASSWORD_HINTS_TEST_IDS.SUCCESS}
      >
        {translate(successMessage)}
      </Alert>
    )
  }

  return (
    <div
      className={tw(
        'flex flex-wrap overflow-hidden transition-all duration-250',
        password ? 'mt-4 max-h-124' : 'mt-0 max-h-0',
        className,
      )}
      data-test={password ? PASSWORD_HINTS_TEST_IDS.VISIBLE : PASSWORD_HINTS_TEST_IDS.HIDDEN}
    >
      {PASSWORD_VALIDATION_KEYS.map((err) => {
        const isErrored = errors.includes(err)

        return (
          <div
            className="mb-3 flex h-5 w-1/2 flex-row items-center gap-3"
            key={err}
            data-test={isErrored ? PASSWORD_VALIDATION_TEST_IDS[err] : undefined}
          >
            <svg height={8} width={8}>
              <circle
                cx="4"
                cy="4"
                r="4"
                fill={isErrored ? theme.palette.primary.main : theme.palette.grey[500]}
              />
            </svg>
            <Typography variant="caption" color={isErrored ? 'textSecondary' : 'textPrimary'}>
              {translate(err)}
            </Typography>
          </div>
        )
      })}
    </div>
  )
}
