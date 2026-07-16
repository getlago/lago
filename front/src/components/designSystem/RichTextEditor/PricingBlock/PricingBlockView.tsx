import { NodeViewProps, NodeViewWrapper } from '@tiptap/react'
import { IconName } from 'lago-design-system'

import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { Locale, LocaleEnum } from '~/core/translations'
import { CurrencyEnum } from '~/generated/graphql'
import { useContextualLocale } from '~/hooks/core/useContextualLocale'
import { TranslateFunc, useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

import { OneOffAddOnsPreviewTable } from './OneOffAddOnsPreviewTable'
import { SubscriptionPlanPreviewTable } from './SubscriptionPlanPreviewTable'

import { type EntityData, useRichTextEditorContext } from '../common/RichTextEditorContext'
import { PricingType } from '../extensions/PricingBlock.schema'
import SlashCommandBlockWrapper from '../SlashCommandBlockWrapper/SlashCommandBlockWrapper'

export const PRICING_BLOCK_VIEW_EMPTY_TEST_ID = 'pricing-block-view-empty'
export const PRICING_BLOCK_VIEW_UNRESOLVED_TEST_ID = 'pricing-block-view-unresolved'

type PricingBlockPreviewProps = {
  pricingType: PricingType
  resolvedEntities: EntityData[]
  hasResolved: boolean
  translate: TranslateFunc
  currency: CurrencyEnum
  locale: LocaleEnum
}

// Preview-mode rendering, split out of PricingBlockView to keep each piece simple.
const PricingBlockPreview = ({
  pricingType,
  resolvedEntities,
  hasResolved,
  translate,
  currency,
  locale,
}: PricingBlockPreviewProps) => {
  if (pricingType === 'addOns' && hasResolved) {
    return (
      <NodeViewWrapper className="spacer" data-type="pricingBlock">
        <OneOffAddOnsPreviewTable
          entities={resolvedEntities}
          translate={translate}
          currency={currency}
          locale={locale}
        />
      </NodeViewWrapper>
    )
  }

  const planEntity =
    pricingType === 'plan' ? resolvedEntities.find((e) => e.entityType === 'plan') : undefined

  if (planEntity?.plan) {
    return (
      <NodeViewWrapper className="spacer" data-type="pricingBlock">
        <SubscriptionPlanPreviewTable
          data={planEntity.plan}
          translate={translate}
          currency={currency}
          locale={locale}
        />
      </NodeViewWrapper>
    )
  }

  // Preview mode never renders the interactive empty/summary UI.
  return <NodeViewWrapper className="spacer" data-type="pricingBlock" />
}

export const PricingBlockView = ({ node, updateAttributes }: NodeViewProps) => {
  const { entities, onPricingCommand, mode, customerLocale, customerCurrency } =
    useRichTextEditorContext()
  const { translate } = useInternationalization()
  const { organization } = useOrganizationInfos()
  const currency = customerCurrency ?? organization?.defaultCurrency ?? CurrencyEnum.Usd

  const effectiveLocale: Locale = (customerLocale ?? 'en') as Locale
  const { translateWithContextualLocal } = useContextualLocale(effectiveLocale)

  const pricingType = (node.attrs.pricingType ?? 'plan') as PricingType
  const entityIds = (node.attrs.entityIds ?? []) as string[]
  const localEntityIds = (node.attrs.localEntityIds ?? []) as string[]
  const isEmpty = entityIds.length === 0

  const lookupIds = localEntityIds.length > 0 ? localEntityIds : entityIds
  const resolvedEntities = lookupIds.map((id) => entities[id]).filter(Boolean)
  const hasResolved = resolvedEntities.length > 0

  // Preview mode: dispatch by pricing type
  if (mode === 'preview') {
    return (
      <PricingBlockPreview
        pricingType={pricingType}
        resolvedEntities={resolvedEntities}
        hasResolved={hasResolved}
        translate={translateWithContextualLocal}
        currency={currency}
        locale={LocaleEnum[effectiveLocale]}
      />
    )
  }

  const handleClick = () => {
    onPricingCommand?.({
      onSave: (attrs) => {
        updateAttributes(attrs)
      },
      editData: isEmpty ? undefined : { pricingType, entityIds, localEntityIds },
    })
  }

  if (isEmpty) {
    return (
      <NodeViewWrapper className="spacer" data-type="pricingBlock">
        <div className="block-wrapper">
          <button
            className="pricing-block pricing-block--empty"
            onMouseDown={(e) => e.stopPropagation()}
            onClick={handleClick}
            tabIndex={0}
            data-test={PRICING_BLOCK_VIEW_EMPTY_TEST_ID}
          >
            <span className="pricing-block__placeholder">Select pricing</span>
          </button>
        </div>
      </NodeViewWrapper>
    )
  }

  if (hasResolved) {
    const displayText =
      pricingType === 'plan'
        ? `${resolvedEntities[0].name}`
        : translate('text_17803276502818bsd9sn8888', {
            subtotal: intlFormatNumber(
              resolvedEntities.reduce(
                (sum, entity) => sum + Number.parseFloat(entity.totalAmount ?? '0'),
                0,
              ),
              { currency },
            ),
          })

    const captionTextPrefix = pricingType === 'plan' ? `${resolvedEntities[0].code}` : undefined

    const typeText = translate('text_1779802343219a1cl5ckvtrn')

    const icon: IconName = pricingType === 'plan' ? 'board' : 'document'

    return (
      <NodeViewWrapper className="spacer" data-type="pricingBlock">
        <div className="block-wrapper">
          <SlashCommandBlockWrapper
            typeText={typeText}
            handleClick={handleClick}
            icon={icon}
            displayText={displayText}
            captionTextPrefix={captionTextPrefix}
          />
        </div>
      </NodeViewWrapper>
    )
  }

  // Unresolved state: entityIds present but no matching entity data in context
  const fallbackText =
    pricingType === 'plan' ? `Plan: ${entityIds[0]}` : `Add-ons: ${entityIds.join(', ')}`

  return (
    <NodeViewWrapper className="spacer" data-type="pricingBlock">
      <div className="block-wrapper">
        <div className="pricing-block" data-test={PRICING_BLOCK_VIEW_UNRESOLVED_TEST_ID}>
          <div className="pricing-block__unresolved">
            <span>{fallbackText}</span>
          </div>
        </div>
      </div>
    </NodeViewWrapper>
  )
}
