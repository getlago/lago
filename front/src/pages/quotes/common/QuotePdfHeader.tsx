import { Typography } from '~/components/designSystem/Typography'

import type { QuotePdfHeaderData } from './buildQuotePreviewProps'

/**
 * One-time header rendered at the top of page 1 of a quote / order-form PDF.
 *
 * Mounted live (off-screen) by `QuotePdfProvider`, which captures its rendered
 * DOM and injects it into the print iframe. Rendering live — rather than
 * serializing in isolation — is what lets design-system components like
 * `Typography` work: their MUI theme + emotion styles are present in the app's
 * <head>, and `printHtmlContent` copies those stylesheets into the iframe.
 */
export const QuotePdfHeader = ({ header }: { header: QuotePdfHeaderData }) => (
  <div className="flex flex-col">
    {header.rows.map((row, index) => (
      <Typography key={index} variant="caption" color="grey600">
        {row}
      </Typography>
    ))}
  </div>
)
