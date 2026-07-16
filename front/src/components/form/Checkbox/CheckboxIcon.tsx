import { FC } from 'react'

import { tw } from '~/styles/utils'

interface CheckboxCheckedIconProps {
  disabled?: boolean
  focused?: boolean
}

const CheckboxCheckedIcon: FC<CheckboxCheckedIconProps> = ({ disabled, focused }) => {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 16 16"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={tw(
        focused && 'rounded ring',
        disabled ? 'text-grey-400' : 'text-blue-600 hover:text-blue-700 active:text-blue-800',
      )}
      aria-hidden="true"
    >
      <path
        d="M0 4C0 1.79086 1.79086 0 4 0H12C14.2091 0 16 1.79086 16 4V12C16 14.2091 14.2091 16 12 16H4C1.79086 16 0 14.2091 0 12V4Z"
        fill="currentColor"
      />
      <g clipPath="url(#clip0)">
        <path
          fillRule="evenodd"
          clipRule="evenodd"
          d="M6.49994 11C6.59828 11.0001 6.69564 10.9804 6.78625 10.9422C6.87686 10.904 6.95887 10.848 7.02744 10.7775L11.8499 5.85749C11.8976 5.81093 11.9354 5.75532 11.9612 5.69392C11.9871 5.63253 12.0004 5.5666 12.0004 5.49999C12.0004 5.43339 11.9871 5.36745 11.9612 5.30606C11.9354 5.24467 11.8976 5.18906 11.8499 5.14249C11.8035 5.096 11.7484 5.05913 11.6877 5.03396C11.627 5.0088 11.5619 4.99585 11.4962 4.99585C11.4305 4.99585 11.3654 5.0088 11.3047 5.03396C11.244 5.05913 11.1889 5.096 11.1424 5.14249L6.49994 9.88749L4.84994 8.15249C4.75626 8.05937 4.62954 8.0071 4.49744 8.0071C4.36535 8.0071 4.23863 8.05937 4.14494 8.15249C4.09732 8.19906 4.05948 8.25467 4.03365 8.31606C4.00781 8.37745 3.99451 8.44339 3.99451 8.50999C3.99451 8.5766 4.00781 8.64253 4.03365 8.70392C4.05948 8.76532 4.09732 8.82093 4.14494 8.86749L5.96994 10.78C6.11046 10.9207 6.3011 10.9998 6.49994 11Z"
          fill="white"
        />
      </g>
      <defs>
        <clipPath id="clip0">
          <rect width="8" height="8" fill="white" transform="translate(4 4)" />
        </clipPath>
      </defs>
    </svg>
  )
}

const CheckboxUncheckedIcon: FC<CheckboxCheckedIconProps> = ({ disabled, focused }) => {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 16 16"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={tw(
        'text-white',
        focused && 'rounded ring',
        !disabled && 'hover:text-grey-200 active:text-grey-300',
      )}
      aria-hidden="true"
    >
      <rect stroke="#8C95A6" x="0.5" y="0.5" width="15" height="15" rx="3.5" fill="currentColor" />
    </svg>
  )
}

const CheckboxIndeterminateIcon: FC<CheckboxCheckedIconProps> = ({ disabled, focused }) => {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 16 16"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={tw(
        focused && 'rounded ring',
        disabled ? 'text-grey-400' : 'text-blue-600 hover:text-blue-700 active:text-blue-800',
      )}
      aria-hidden="true"
    >
      <path
        d="M0 4C0 1.79086 1.79086 0 4 0H12C14.2091 0 16 1.79086 16 4V12C16 14.2091 14.2091 16 12 16H4C1.79086 16 0 14.2091 0 12V4Z"
        fill="currentColor"
      />
      <path
        d="M4.14645 8.35355C4.24021 8.44732 4.36739 8.5 4.5 8.5H11.5C11.6326 8.5 11.7598 8.44732 11.8536 8.35355C11.9473 8.25979 12 8.13261 12 8C12 7.86739 11.9473 7.74021 11.8536 7.64645C11.7598 7.55268 11.6326 7.5 11.5 7.5H4.5C4.36739 7.5 4.24021 7.55268 4.14645 7.64645C4.05268 7.74021 4 7.86739 4 8C4 8.13261 4.05268 8.25979 4.14645 8.35355Z"
        fill="white"
      />
    </svg>
  )
}

export const CheckboxIcon: FC<
  { value?: boolean; canBeIndeterminate?: boolean } & CheckboxCheckedIconProps
> = ({ value, canBeIndeterminate, ...checkboxIconProps }) => {
  if (value) {
    return <CheckboxCheckedIcon {...checkboxIconProps} />
  }

  if (canBeIndeterminate && value === undefined) {
    return <CheckboxIndeterminateIcon {...checkboxIconProps} />
  }

  return <CheckboxUncheckedIcon />
}
