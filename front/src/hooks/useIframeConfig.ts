import { useSearchParams } from 'react-router-dom'

type TEventData = {
  action: string
  rel: string
  [key: string]: string
}

type TUseIframeConfigReturn = {
  emitIframeMessage: (data: TEventData) => void
  emitSalesForceEvent: (data: TEventData) => void
  isRunningInIframeContext: boolean
  isRunningInSalesForceIframe: boolean
}

/**
 * Pure check for iframe context query params (`?sfdc=true` for Salesforce,
 * `?ifrm=true` for Hubspot). Use when you have a `search` string in hand
 * (e.g. inside a pure resolver, or against a saved Location) and don't want
 * to subscribe to React Router via `useIframeConfig`.
 *
 * Strict `=== 'true'` (not truthy) — defensive: the only valid embed values
 * Salesforce/Hubspot send are `true`. Any other value is treated as "not
 * iframe context" so we don't trigger LS-based slug auto-recovery on bad
 * input.
 */
export const hasIframeParams = (search: string | undefined): boolean => {
  if (!search) return false

  const params = new URLSearchParams(search)

  return params.get('sfdc') === 'true' || params.get('ifrm') === 'true'
}

export const useIframeConfig = (): TUseIframeConfigReturn => {
  const [searchParams] = useSearchParams()

  const isRunningInSalesForceIframe = !!searchParams.get('sfdc')
  const isRunningInIframeContext = !!searchParams.get('ifrm')

  const emitSalesForceEvent = (data: TEventData) => {
    window.parent.postMessage(JSON.stringify(data), '*')
  }

  const emitIframeMessage = (data: TEventData) => {
    window.postMessage(JSON.stringify(data), '*')
  }

  return {
    isRunningInSalesForceIframe,
    isRunningInIframeContext,
    emitSalesForceEvent,
    emitIframeMessage,
  }
}
