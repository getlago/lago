const serializeDataToString = (data: DataType): string => {
  const extractedDataString = JSON.stringify(data, null, 2)
  const extractedDataStringIndented = extractedDataString.replace(/^(?=.)/gm, '  ').trimStart()

  return extractedDataStringIndented
}

type DataType = Record<string, unknown>

interface CurlCommand {
  title: string
  url: string
  method: 'POST' | 'PUT'
  headers: Array<Record<string, string>>
  data: DataType
  footerComment?: string
}

export enum SnippetVariables {
  EXTERNAL_CUSTOMER_ID = '__EXTERNAL_CUSTOMER_ID__',
  EXTERNAL_SUBSCRIPTION_ID = '__EXTERNAL_SUBSCRIPTION_ID__',
  MUST_BE_DEFINED = '__MUST_BE_DEFINED__',
  API_KEY = '__YOUR_API_KEY__',
  UNIQUE_ID = '__UNIQUE_ID__',
}

/**
 * Helper function to build a curl command snippet
 * @returns string
 */
export const snippetBuilder = (curlCommand: CurlCommand): string => {
  const { title, url, method, headers, data, footerComment } = curlCommand

  return `\
# ${title}
curl --location --request ${method} "${url}" \\
${headers
  .map((header) => {
    const [key] = Object.keys(header)

    return `  --header "${key}: ${header[key]}" \\`
  })
  .join('\n')}
  --data-raw '${serializeDataToString(data)}'
${
  footerComment
    ? `
# ${footerComment}`
    : ''
}\
`
}
