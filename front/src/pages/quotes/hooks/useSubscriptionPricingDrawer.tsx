import { useCallback, useEffect, useMemo, useRef, useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import type {
  EntityData,
  OnPricingCommand,
} from '~/components/designSystem/RichTextEditor/common/RichTextEditorContext'
import type { PricingBlockAttributes } from '~/components/designSystem/RichTextEditor/extensions/PricingBlock.schema'
import { SubscriptionPricingContent } from '~/components/designSystem/RichTextEditor/PricingBlock/SubscriptionPricingContent'
import { useFormDrawer } from '~/components/drawers/useDrawer'
import type { PlanFormInput } from '~/components/plans/types'
import type { BillingItemsPayload } from '~/core/serializers/serializeQuoteBillingItems'
import {
  fromPlanBillingItems,
  type SubscriptionPricingState,
  toPlanBillingItems,
} from '~/core/serializers/serializeQuotePlanBillingItems'
import { useInternationalization } from '~/hooks/core/useInternationalization'

interface UseSubscriptionPricingDrawerReturn {
  onPricingCommand: OnPricingCommand
  isPricingDisabled: () => boolean
  entities: Record<string, EntityData>
  syncEntitiesWithBlocks: (blocks: PricingBlockAttributes[]) => BillingItemsPayload | null
}

export interface QuoteCustomer {
  id: string
  externalId: string
  name?: string | null
}

export interface SubscriptionPricingDrawerOptions {
  quoteDates?: { startDate?: string; endDate?: string }
  onDatesChange?: (startDate?: string, endDate?: string) => void
  customer?: QuoteCustomer | null
  subscriptionId?: string
}

export const useSubscriptionPricingDrawer = (
  initialBillingItems?: unknown,
  options?: SubscriptionPricingDrawerOptions,
): UseSubscriptionPricingDrawerReturn => {
  const { translate } = useInternationalization()
  const drawer = useFormDrawer()

  const [entities, setEntities] = useState<Record<string, EntityData>>({})
  const entitiesRef = useRef<Record<string, EntityData>>({})
  const initialStateRef = useRef<SubscriptionPricingState | null>(null)
  const subscriptionStateRef = useRef<SubscriptionPricingState | null>(null)
  const formValuesRef = useRef<PlanFormInput | null>(null)

  // Latest saved billingItems, kept in a ref so plan saves/syncs can preserve
  // sibling categories (coupons, addons) instead of overwriting billingItems and
  // dropping them — each drawer only owns its own slice of billingItems.
  const latestBillingItemsRef = useRef<BillingItemsPayload | undefined>(undefined)

  useEffect(() => {
    latestBillingItemsRef.current =
      (initialBillingItems as BillingItemsPayload | undefined) ?? undefined
  }, [initialBillingItems])

  // Determine initialization case: extract billing item plan for case 2
  const billingItemPlan = useMemo(() => {
    if (!initialBillingItems) return undefined
    const parsed = initialBillingItems as BillingItemsPayload

    return parsed.plans?.[0]
  }, [initialBillingItems])
  const onSaveRef = useRef<
    | ((
        attrs: PricingBlockAttributes,
        entityData: Record<string, EntityData>,
        billingItems?: BillingItemsPayload,
      ) => void)
    | null
  >(null)

  // Hydration: populate entities from saved billing items on mount
  useEffect(() => {
    if (!initialBillingItems) return

    const parsed = initialBillingItems as BillingItemsPayload

    if (!parsed.plans?.length) return

    const result = fromPlanBillingItems(parsed.plans)

    initialStateRef.current = {
      planId: result.planId,
      planCode: result.planCode,
      planName: result.planName,
      planDescription: result.planDescription,
      subscriptionSettings: result.subscriptionSettings,
      invoicingSettings: result.invoicingSettings,
      overrides: result.overrides,
    }

    entitiesRef.current = { ...entitiesRef.current, ...result.entityData }
    setEntities({ ...entitiesRef.current })
  }, [initialBillingItems])

  const onPricingCommand = useCallback<OnPricingCommand>(
    ({ onSave }) => {
      onSaveRef.current = onSave

      const handleSave = () => {
        const state = subscriptionStateRef.current
        const formValues = formValuesRef.current

        if (!state) return

        const billingItems = toPlanBillingItems(state, formValues ?? undefined)
        const entityData: Record<string, EntityData> = {
          [state.planId]: {
            entityId: state.planId,
            entityType: 'plan',
            name: state.planName,
            code: state.planCode,
          },
        }

        entitiesRef.current = { ...entitiesRef.current, ...entityData }
        setEntities({ ...entitiesRef.current })

        onSaveRef.current?.({ pricingType: 'plan', entityIds: [state.planId] }, entityData, {
          ...latestBillingItemsRef.current,
          ...billingItems,
        })

        // Propagate date changes to the quote level
        options?.onDatesChange?.(
          state.subscriptionSettings.startDate || undefined,
          state.subscriptionSettings.endDate || undefined,
        )

        drawer.close()
      }

      drawer.open({
        title: translate('text_17791987800302plb0guzxzv'),
        form: {
          id: 'subscription-pricing-drawer-form',
          submit: handleSave,
        },
        mainAction: (
          <Button data-test="subscription-pricing-drawer-submit" type="submit">
            {translate('text_17295436903260tlyb1gp1i7')}
          </Button>
        ),
        children: (
          <SubscriptionPricingContent
            stateRef={subscriptionStateRef}
            formValuesRef={formValuesRef}
            initialState={initialStateRef.current}
            quoteDates={options?.quoteDates}
            customer={options?.customer}
            billingItemPlan={billingItemPlan}
            subscriptionId={billingItemPlan ? undefined : options?.subscriptionId}
          />
        ),
      })
    },
    [translate, drawer, options, billingItemPlan],
  )

  const isPricingDisabled = useCallback(() => Object.keys(entitiesRef.current).length > 0, [])

  const syncEntitiesWithBlocks = useCallback(
    (blocks: PricingBlockAttributes[]): BillingItemsPayload | null => {
      const activeEntityIds = new Set(blocks.flatMap((b) => b.entityIds))
      const currentKeys = Object.keys(entitiesRef.current)
      const orphanedKeys = currentKeys.filter((id) => !activeEntityIds.has(id))

      if (orphanedKeys.length === 0) return null

      const updatedEntities = { ...entitiesRef.current }

      for (const key of orphanedKeys) {
        delete updatedEntities[key]
      }

      entitiesRef.current = updatedEntities
      setEntities(updatedEntities)

      // Only the plan is this drawer's responsibility; sibling categories
      // (coupons, addons) are carried through untouched.
      return { ...latestBillingItemsRef.current, plans: [] }
    },
    [],
  )

  return { onPricingCommand, isPricingDisabled, entities, syncEntitiesWithBlocks }
}
