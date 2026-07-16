import { OPTION_VALUE_SEPARATOR } from './const'

export const stringifyOptionValue = ({
  externalId,
  externalAccountCode,
  externalName,
}: {
  externalId: string
  externalAccountCode: string
  externalName: string
}) => {
  return `${externalId}${OPTION_VALUE_SEPARATOR}${externalAccountCode}${OPTION_VALUE_SEPARATOR}${externalName}`
}
