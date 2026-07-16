import {
  createContext,
  FC,
  PropsWithChildren,
  useCallback,
  useContext,
  useMemo,
  useRef,
  useState,
} from 'react'

import { MainHeaderConfig } from './types'

interface MainHeaderWriteContextValue {
  setConfig: (config: MainHeaderConfig) => void
  resetConfig: () => void
  registerConfigure: () => void
  unregisterConfigure: () => void
}

const MainHeaderWriteContext = createContext<MainHeaderWriteContextValue | undefined>(undefined)

interface MainHeaderReadContextValue {
  config: MainHeaderConfig | null
}

const MainHeaderReadContext = createContext<MainHeaderReadContextValue | undefined>(undefined)

export const MainHeaderProvider: FC<PropsWithChildren> = ({ children }) => {
  const [config, setConfig] = useState<MainHeaderConfig | null>(null)
  const mountCountRef = useRef(0)

  const resetConfig = useCallback(() => {
    setConfig(null)
  }, [])

  const registerConfigure = useCallback(() => {
    mountCountRef.current += 1

    if (process.env.NODE_ENV === 'development' && mountCountRef.current > 1) {
      // eslint-disable-next-line no-console
      console.log(
        `[MainHeader] ${mountCountRef.current} Configure instances mounted simultaneously and only the last one will be applied.\n` +
          `If intentional (e.g. nested override), you can safely ignore this notice.`,
      )
    }
  }, [])

  const unregisterConfigure = useCallback(() => {
    mountCountRef.current -= 1
  }, [])

  // Stable — all callbacks are memoized with empty deps, so this never changes
  const writeValue = useMemo(
    () => ({ setConfig, resetConfig, registerConfigure, unregisterConfigure }),
    [setConfig, resetConfig, registerConfigure, unregisterConfigure],
  )

  // Reactive — changes when config changes
  const readValue = useMemo(() => ({ config }), [config])

  return (
    <MainHeaderWriteContext.Provider value={writeValue}>
      <MainHeaderReadContext.Provider value={readValue}>{children}</MainHeaderReadContext.Provider>
    </MainHeaderWriteContext.Provider>
  )
}

/** Used by Configure — write-only, never re-renders on config change */
export const useMainHeaderWriter = () => {
  const context = useContext(MainHeaderWriteContext)

  if (context === undefined) {
    throw new Error('useMainHeaderWriter must be used within a MainHeaderProvider')
  }

  return context
}

/** Used by MainHeader — read-only, re-renders when config changes */
export const useMainHeaderReader = () => {
  const context = useContext(MainHeaderReadContext)

  if (context === undefined) {
    throw new Error('useMainHeaderReader must be used within a MainHeaderProvider')
  }

  return context
}
