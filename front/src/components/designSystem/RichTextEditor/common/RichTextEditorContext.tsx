import { createContext, useContext } from 'react'

import type { PlanPreviewData } from '~/core/serializers/buildPlanPreviewData'
import type { BillingItemsPayload } from '~/core/serializers/serializeQuoteBillingItems'
import type { Locale } from '~/core/translations'
import { type CouponFrequency, type CouponTypeEnum, type CurrencyEnum } from '~/generated/graphql'

import type { DiscountBlockAttributes } from '../extensions/DiscountBlock.schema'
import type { PricingBlockAttributes, PricingType } from '../extensions/PricingBlock.schema'
import type { RichTextEditorMode } from '../RichTextEditor'

export type EntityData = {
  entityId: string
  entityType: 'plan' | 'addOn' | 'coupon'
  name: string
  invoiceDisplayName?: string
  code: string
  description?: string
  units?: string
  unitAmountCents?: string
  totalAmount?: string
  fromDatetime?: string
  toDatetime?: string
  plan?: PlanPreviewData
  // coupon-only display fields
  couponType?: CouponTypeEnum
  amountCents?: string
  amountCurrency?: CurrencyEnum
  percentageRate?: number | null
  frequency?: CouponFrequency
  frequencyDuration?: number | null
}

interface PricingCommandParams {
  onSave: (
    attrs: PricingBlockAttributes,
    entityData: Record<string, EntityData>,
    billingItems?: BillingItemsPayload,
  ) => void
  editData?: { pricingType: PricingType; entityIds: string[]; localEntityIds?: string[] }
}

export type OnPricingCommand = (params: PricingCommandParams) => void

export interface DiscountCommandParams {
  onSave: (attrs: DiscountBlockAttributes) => void
  editData?: { couponId: string; localId: string }
}

export type OnDiscountCommand = (params: DiscountCommandParams) => void

interface RichTextEditorContextValue {
  mode: RichTextEditorMode
  mentionValues: Record<string, string>
  entities: Record<string, EntityData>
  images: Record<string, string>
  onPricingCommand?: OnPricingCommand
  onImageUpload?: (base64: string) => Promise<string>
  onDiscountCommand?: OnDiscountCommand
  customerLocale?: Locale
  customerCurrency?: CurrencyEnum
}

const RichTextEditorContext = createContext<RichTextEditorContextValue>({
  mode: 'edit',
  mentionValues: {},
  entities: {},
  images: {},
})

export const RichTextEditorProvider = RichTextEditorContext.Provider

export const useRichTextEditorContext = () => useContext(RichTextEditorContext)
