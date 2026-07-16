import { FC } from 'react'

import { tw } from '~/styles/utils'

interface RadioIconProps {
  focused?: boolean
  disabled?: boolean
}

const RadioCheckedIcon: FC<RadioIconProps> = ({ focused, disabled }) => {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 16 16"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={tw(focused && 'rounded-full ring')}
    >
      <circle
        className={tw('fill-blue-700', disabled && 'fill-grey-400')}
        cx="8"
        cy="8"
        r="8"
        fill="currentColor"
      />
      <circle
        className="group-hover/radio-icon:fill-blue-100 group-active/radio-icon:fill-blue-200"
        cx="8"
        cy="8"
        r="7"
        fill="white"
      />
      <circle
        className={tw('fill-blue-700', disabled && 'fill-grey-400')}
        cx="8"
        cy="8"
        r="4"
        fill="currentColor"
      />
    </svg>
  )
}

const RadioUncheckedIcon: FC<RadioIconProps> = ({ focused, disabled }) => {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 16 16"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={tw(focused && 'rounded-full ring')}
    >
      <circle className={tw(disabled && 'fill-grey-400')} cx="8" cy="8" r="8" fill="currentColor" />
      <circle
        className="group-hover/radio-icon:fill-grey-200 group-active/radio-icon:fill-grey-300"
        cx="8"
        cy="8"
        r="7"
        fill="white"
      />
    </svg>
  )
}

export const RadioIcon: FC<{ checked: boolean } & RadioIconProps> = ({
  checked,
  ...radioIconProps
}) => {
  return checked ? (
    <RadioCheckedIcon {...radioIconProps} />
  ) : (
    <RadioUncheckedIcon {...radioIconProps} />
  )
}
