export const addValuesToUrlState = ({
  url,
  values,
  stateType,
}: {
  url: string
  values: Record<string, string>
  stateType: 'string' | 'object'
}) => {
  const urlObj = new URL(url)
  const urlSearchParams = urlObj.searchParams

  const oldState = urlSearchParams.get('state') || ('{}' as string)

  let state = {}

  if (stateType === 'string') {
    state = { state: oldState, ...values }
  } else if (stateType === 'object') {
    const parsedState = JSON.parse(oldState)

    state = { ...parsedState, ...values }
  }

  urlSearchParams.set('state', decodeURI(JSON.stringify(state)))
  urlObj.search = urlSearchParams.toString()

  return urlObj.toString()
}
