import { createContext, ReactNode, useContext, useMemo } from 'react'

import { CurrencyEnum, PlanInterval } from '~/generated/graphql'

interface PlanFormContextValue {
  currency: CurrencyEnum
  interval: PlanInterval
}

const PlanFormContext = createContext<PlanFormContextValue | null>(null)

interface PlanFormProviderProps extends PlanFormContextValue {
  children: ReactNode
}

export const PlanFormProvider = ({ currency, interval, children }: PlanFormProviderProps) => {
  const value = useMemo(() => ({ currency, interval }), [currency, interval])

  return <PlanFormContext.Provider value={value}>{children}</PlanFormContext.Provider>
}

export const usePlanFormContext = (): PlanFormContextValue => {
  const context = useContext(PlanFormContext)

  if (!context) {
    throw new Error('usePlanFormContext must be used within a PlanFormProvider')
  }

  return context
}
