import { addToast } from '~/core/apolloClient'

const filterComment = (value: string) => {
  return value
    .split('\n')
    .filter((line) => !line.startsWith('#'))
    .join('\n')
}

const unsecuredCopyToClipboard = (text: string) => {
  const textArea = document.createElement('textarea')

  textArea.value = text.trim()
  document.body.appendChild(textArea)
  textArea.focus()
  textArea.select()
  try {
    document.execCommand('copy')
  } catch {
    addToast({
      severity: 'danger',
      translateKey: 'text_1745919770448pvibiukolis',
    })
    throw new Error('Unable to copy to clipboard')
  } finally {
    document.body.removeChild(textArea)
  }
}

export const copyToClipboard: (value: string, options?: { ignoreComment?: boolean }) => void = (
  value,
  ignoreComment,
) => {
  const serializedValue = ignoreComment ? filterComment(value) : value

  try {
    navigator.clipboard.writeText(serializedValue)
  } catch {
    unsecuredCopyToClipboard(serializedValue)
    addToast({
      severity: 'info',
      translateKey: 'text_63a5ba11eb4e7e17ef88e9f0',
    })
  }
}
