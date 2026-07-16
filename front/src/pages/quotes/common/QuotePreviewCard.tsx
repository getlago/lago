import RichTextEditor from '~/components/designSystem/RichTextEditor/RichTextEditor'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import type { QuotePdfHeaderData, QuotePreviewProps } from './buildQuotePreviewProps'
import { QuotePdfHeader } from './QuotePdfHeader'

interface QuotePreviewCardProps {
  header: QuotePdfHeaderData
  /** Whether the quote version has content to render. */
  hasContent: boolean
  previewProps: QuotePreviewProps
  loading?: boolean
  dataTest?: string
}

/**
 * Read-only quote document preview, rendered as a bordered card on the grey
 * `Side` panel of the void pages. The header line mirrors the quote PDF
 * document number; the body is the read-only `RichTextEditor` preview.
 */
export const QuotePreviewCard = ({
  header,
  hasContent,
  previewProps,
  loading,
  dataTest,
}: QuotePreviewCardProps) => {
  const { translate } = useInternationalization()

  return (
    <div className="p-8" data-test={dataTest}>
      <div className="mx-auto flex w-full max-w-180 flex-col gap-8 rounded-xl border border-grey-300 bg-white p-8">
        {loading ? (
          <div className="flex flex-col gap-4">
            <Skeleton variant="text" className="w-3/4" />
            <Skeleton variant="text" className="w-full" />
            <Skeleton variant="text" className="w-5/6" />
          </div>
        ) : (
          <>
            <QuotePdfHeader header={header} />
            {hasContent ? (
              <RichTextEditor mode="preview" isCompact {...previewProps} />
            ) : (
              <Typography color="grey500">{translate('text_17768523811635qaasto1ziv')}</Typography>
            )}
          </>
        )}
      </div>
    </div>
  )
}
