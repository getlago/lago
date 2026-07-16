export const buildWebSocketUrl = (apiUrl: string): { websocketUrl: string; cableUrl: string } => {
  const apiUrlObj = new URL(apiUrl)
  const wsProtocol = apiUrlObj.protocol === 'https:' ? 'wss:' : 'ws:'

  apiUrlObj.protocol = wsProtocol
  apiUrlObj.pathname = apiUrlObj.pathname.replace(/\/$/, '')

  let websocketUrl = apiUrlObj.toString()

  websocketUrl = websocketUrl.replace(/\/(?=\?|#|$)/, '')

  let cableUrl: string

  if (websocketUrl.includes('?') || websocketUrl.includes('#')) {
    const queryIndex = websocketUrl.indexOf('?')
    const hashIndex = websocketUrl.indexOf('#')
    const insertIndex = Math.min(
      queryIndex === -1 ? Infinity : queryIndex,
      hashIndex === -1 ? Infinity : hashIndex,
    )

    cableUrl = websocketUrl.slice(0, insertIndex) + '/cable' + websocketUrl.slice(insertIndex)
  } else {
    cableUrl = `${websocketUrl}/cable`
  }

  return { websocketUrl, cableUrl }
}
