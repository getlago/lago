import { FC, useEffect, useLayoutEffect, useRef } from 'react'

import { useMainHeaderWriter } from './MainHeaderContext'
import { MainHeaderConfig } from './types'

/**
 * Serializable snapshot of the config. The JSON.stringify replacer automatically
 * strips functions (onClick callbacks) and the `content` key (ReactNode in tabs).
 * Everything else — primitives, labels, flags — is kept.
 *
 * Used by Configure to detect meaningful changes: same snapshot → skip setConfig.
 */
function configSnapshot(config: MainHeaderConfig): string {
  return JSON.stringify(config, (key, value) => {
    if (typeof value === 'function') return undefined
    if (key === 'content') return undefined
    if (key === 'filtersSection') return undefined
    if (key === 'icon' && typeof value !== 'string') return undefined
    if (key === 'snapshotKey') return value

    // ReactNode values (e.g. a node passed as `metadata`) are non-serializable:
    // dev-mode React elements carry a circular `_owner` Fiber that links back to
    // a DOM node, which crashes JSON.stringify. Strip any React element/portal,
    // mirroring how `content` and non-string `icon` nodes are already dropped.
    if (value && typeof value === 'object' && '$$typeof' in value) return undefined

    return value
  })
}

/**
 * Declarative zero-render component that configures the MainHeader.
 * Works like <Helmet> / <Head> — renders nothing, communicates via Context.
 *
 * Loop prevention: a snapshot is computed from the config
 * on every render. The useLayoutEffect only calls setConfig when the snapshot
 * changes, so context-triggered re-renders (which produce the same data,
 * just new object references) are silently ignored. No useMemo required
 * from consumer pages.
 *
 * useLayoutEffect is used instead of useEffect for both setting and cleanup
 * so that header transitions happen synchronously before the browser paints.
 * This prevents the old header from lingering during route changes.
 */
export const MainHeaderConfigure: FC<MainHeaderConfig> = (props) => {
  const { setConfig, resetConfig, registerConfigure, unregisterConfigure } = useMainHeaderWriter()

  // Ref keeps the latest props available for the useLayoutEffect,
  // so setConfig always receives the freshest values.
  const propsRef = useRef(props)

  propsRef.current = props

  // Track mount/unmount for dev warning on multiple instances
  useEffect(() => {
    registerConfigure()

    return () => unregisterConfigure()
  }, [registerConfigure, unregisterConfigure])

  // Only push to context when the visual snapshot changes.
  // Context-triggered re-renders produce identical snapshots → no setConfig → no loop.
  const snapshot = configSnapshot(props)

  useLayoutEffect(() => {
    setConfig(propsRef.current)
  }, [snapshot, setConfig])

  // Cleanup on unmount — reset config to null.
  // useLayoutEffect ensures the reset happens before paint, so the old
  // header never lingers when navigating to a different view.
  useLayoutEffect(() => {
    return () => resetConfig()
  }, [resetConfig])

  return null
}
