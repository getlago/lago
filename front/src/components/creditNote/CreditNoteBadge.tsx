import {
  CREDIT_NOTE_TYPE_TRANSLATIONS_MAP,
  CreditNoteType,
  formatCreditNoteTypesForDisplay,
  getCreditNoteTypes,
} from '~/components/creditNote/utils'
import { Chip } from '~/components/designSystem/Chip'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { CreditNote, CreditNoteTableItemFragment } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

const CreditNoteBadge = ({
  creditNote,
}: {
  creditNote?: CreditNoteTableItemFragment | CreditNote | null
}) => {
  const { translate } = useInternationalization()

  if (!creditNote) return null

  const { creditAmountCents, refundAmountCents, offsetAmountCents, voidedAt, taxProviderSyncable } =
    creditNote

  // Handle voided credit notes
  if (voidedAt) {
    return <Chip label={translate(CREDIT_NOTE_TYPE_TRANSLATIONS_MAP[CreditNoteType.VOIDED])} />
  }

  const types = getCreditNoteTypes({
    creditAmountCents,
    refundAmountCents,
    offsetAmountCents,
  })

  if (types.length === 0) return null

  const hasMultipleTypes = types.length > 1
  const hasError = taxProviderSyncable

  // Build tooltip content
  const getTooltipContent = () => {
    if (hasMultipleTypes) {
      const translatedTypes = types.map((type) =>
        translate(CREDIT_NOTE_TYPE_TRANSLATIONS_MAP[type]),
      )

      return formatCreditNoteTypesForDisplay(translatedTypes)
    }

    if (hasError) {
      return translate('text_1727090499191gqzispoy1qz')
    }

    return null
  }

  const tooltipContent = getTooltipContent()

  const label = hasMultipleTypes
    ? translate(CREDIT_NOTE_TYPE_TRANSLATIONS_MAP.MULTIPLE_TYPES)
    : translate(CREDIT_NOTE_TYPE_TRANSLATIONS_MAP[types[0]])

  return (
    <Tooltip title={tooltipContent} placement="top-start">
      <Chip label={label} icon={hasError ? 'warning-unfilled' : undefined} />
    </Tooltip>
  )
}

export default CreditNoteBadge
