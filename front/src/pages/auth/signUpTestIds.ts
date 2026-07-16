// Data test ids for SignUp – shared with e2e. No app imports so Cypress can bundle this file alone.
// Password validation test IDs match PASSWORD_HINTS_TEST_IDS from PasswordValidationHints component

export const SIGNUP_ORGANIZATION_NAME_FIELD_TEST_ID = 'signup-organization-name-field'
export const SIGNUP_EMAIL_FIELD_TEST_ID = 'signup-email-field'
export const SIGNUP_PASSWORD_FIELD_TEST_ID = 'signup-password-field'
export const SIGNUP_ERROR_ALERT_TEST_ID = 'signup-error-alert'
export const SIGNUP_SUBMIT_BUTTON_TEST_ID = 'signup-submit-button'

// Re-exported for e2e backward compatibility - values match PASSWORD_HINTS_TEST_IDS
export const SIGNUP_PASSWORD_VALIDATION_VISIBLE_TEST_ID = 'password-validation--visible'
export const SIGNUP_PASSWORD_VALIDATION_HIDDEN_TEST_ID = 'password-validation--hidden'
export const SIGNUP_SUCCESS_ALERT_TEST_ID = 'password-validation--success'
