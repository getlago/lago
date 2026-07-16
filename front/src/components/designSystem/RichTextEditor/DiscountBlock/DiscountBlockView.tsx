import { NodeViewProps, NodeViewWrapper } from '@tiptap/react'

import { Locale, LocaleEnum } from '~/core/translations'
import { CurrencyEnum } from '~/generated/graphql'
import { useContextualLocale } from '~/hooks/core/useContextualLocale'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

import { DiscountPreviewTable } from './DiscountPreviewTable'

import { useRichTextEditorContext } from '../common/RichTextEditorContext'
import SlashCommandBlockWrapper from '../SlashCommandBlockWrapper/SlashCommandBlockWrapper'

export const DISCOUNT_BLOCK_VIEW_EMPTY_TEST_ID = 'discount-block-view-empty'
export const DISCOUNT_BLOCK_VIEW_UNRESOLVED_TEST_ID = 'discount-block-view-unresolved'

export const DiscountBlockView = ({ node, updateAttributes }: NodeViewProps) => {
  const { entities, onDiscountCommand, mode, customerLocale, customerCurrency } =
    useRichTextEditorContext()
  const { translate } = useInternationalization()
  const { organization } = useOrganizationInfos()
  const currency = customerCurrency ?? organization?.defaultCurrency ?? CurrencyEnum.Usd

  const effectiveLocale: Locale = (customerLocale ?? 'en') as Locale
  const { translateWithContextualLocal } = useContextualLocale(effectiveLocale)

  const couponId = (node.attrs.couponId ?? '') as string
  const localId = (node.attrs.localId ?? '') as string
  const isEmpty = couponId === ''

  const entity = (localId && entities[localId]) || (couponId && entities[couponId]) || undefined

  // Preview mode: read-only, non-interactive
  if (mode === 'preview') {
    if (entity) {
      return (
        <NodeViewWrapper className="spacer" data-type="discountBlock">
          <DiscountPreviewTable
            entity={entity}
            translate={translateWithContextualLocal}
            currency={currency}
            locale={LocaleEnum[effectiveLocale]}
          />
        </NodeViewWrapper>
      )
    }

    // Empty or unresolved in preview — render nothing interactive
    return <NodeViewWrapper className="spacer" data-type="discountBlock" />
  }

  const handleClick = () => {
    onDiscountCommand?.({
      onSave: (attrs) => updateAttributes(attrs),
      editData: isEmpty ? undefined : { couponId, localId },
    })
  }

  if (isEmpty) {
    return (
      <NodeViewWrapper className="spacer" data-type="discountBlock">
        <div className="block-wrapper">
          <button
            className="pricing-block pricing-block--empty"
            onMouseDown={(e) => e.stopPropagation()}
            onClick={handleClick}
            tabIndex={0}
            data-test={DISCOUNT_BLOCK_VIEW_EMPTY_TEST_ID}
          >
            <span className="pricing-block__placeholder">
              {translate('text_1783342959387sv77znuw5yx')}
            </span>
          </button>
        </div>
      </NodeViewWrapper>
    )
  }

  if (entity) {
    return (
      <NodeViewWrapper className="spacer" data-type="discountBlock">
        <div className="block-wrapper">
          <SlashCommandBlockWrapper
            typeText={translate('text_1782889379261hdcd0jhzdm6')}
            handleClick={handleClick}
            icon="coupon"
            displayText={entity.name}
          />
        </div>
      </NodeViewWrapper>
    )
  }

  return (
    <NodeViewWrapper className="spacer" data-type="discountBlock">
      <div className="block-wrapper">
        <div className="pricing-block" data-test={DISCOUNT_BLOCK_VIEW_UNRESOLVED_TEST_ID}>
          <div className="pricing-block__unresolved">
            <span>{translate('text_1783342959387cz07147m6qq', { couponId })}</span>
          </div>
        </div>
      </div>
    </NodeViewWrapper>
  )
}
