import { OPTION_VALUE_SEPARATOR } from './const'

export const extractOptionValue = (
  optionValue: string,
): {
  externalId: string | undefined
  externalAccountCode: string | undefined
  externalName: string | undefined
} => {
  if (!optionValue) {
    return {
      externalId: undefined,
      externalAccountCode: undefined,
      externalName: undefined,
    }
  }

  const [externalId, externalAccountCode, externalName] = optionValue.split(OPTION_VALUE_SEPARATOR)

  return { externalId, externalAccountCode, externalName }
}
