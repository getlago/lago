import { type AnyFormApi, useStore } from '@tanstack/react-form'
import { createContext, type ReactNode, useContext, useMemo } from 'react'

import { LocalChargeFilterInput } from '~/components/plans/types'
import { CurrencyEnum, PropertiesInput } from '~/generated/graphql'

/** AnyFormApi + AppField from createFormHook — field callback is typed at each call site */
export interface ChargeForm extends AnyFormApi {
  AppField(props: Record<string, unknown>): ReactNode
}

interface ChargeFormContextValue {
  form: AnyFormApi
  propertyCursor: string
  currency: CurrencyEnum
  disabled?: boolean
  chargePricingUnitShortName: string | undefined
}

/** What useChargeFormContext returns — form is widened to ChargeForm (includes AppField) */
interface ChargeFormContextReturn {
  form: ChargeForm
  propertyCursor: string
  currency: CurrencyEnum
  disabled?: boolean
  chargePricingUnitShortName: string | undefined
}

const ChargeFormContext = createContext<ChargeFormContextValue | null>(null)

export const ChargeFormProvider = ({
  children,
  ...value
}: ChargeFormContextValue & { children: ReactNode }) => {
  const memoized = useMemo(
    () => value,
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [
      value.form,
      value.propertyCursor,
      value.currency,
      value.disabled,
      value.chargePricingUnitShortName,
    ],
  )

  return <ChargeFormContext.Provider value={memoized}>{children}</ChargeFormContext.Provider>
}

export const useChargeFormContext = (): ChargeFormContextReturn => {
  const ctx = useContext(ChargeFormContext)

  if (!ctx) throw new Error('useChargeFormContext must be used within a ChargeFormProvider')

  // The form stored in context is always created by createFormHook (useAppForm/withForm)
  // which adds AppField on top of FormApi — safe to widen
  return ctx as ChargeFormContextReturn
}

/** Derive valuePointer reactively from the form store */
export function usePropertyValues(form: AnyFormApi, propertyCursor: string) {
  return useStore(form.store, (s: { values: Record<string, unknown> }) =>
    propertyCursor
      .split('.')
      .reduce<unknown>((obj, key) => (obj as Record<string, unknown> | undefined)?.[key], s.values),
  ) as PropertiesInput | LocalChargeFilterInput['properties'] | undefined
}
