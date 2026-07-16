import { Typography, TypographyProps } from '~/components/designSystem/Typography'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { PURCHASE_ORDER_TRANSLATIONS } from './constants'

export const PURCHASE_ORDER_TITLE_TEST_ID = 'purchase-order-title'

export const PurchaseOrderTitle = ({ children, ...props }: TypographyProps) => {
  const { translate } = useInternationalization()

  return (
    <Typography
      variant="captionHl"
      color="grey700"
      data-test={PURCHASE_ORDER_TITLE_TEST_ID}
      {...props}
    >
      {children || translate(PURCHASE_ORDER_TRANSLATIONS.title)}
    </Typography>
  )
}
