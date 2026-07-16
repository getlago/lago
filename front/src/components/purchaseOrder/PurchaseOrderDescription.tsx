import { Typography, TypographyProps } from '~/components/designSystem/Typography'

import { usePurchaseOrderContext } from './PurchaseOrderContext'

export const PURCHASE_ORDER_DESCRIPTION_TEST_ID = 'purchase-order-description'

export const PurchaseOrderDescription = ({ children, ...props }: TypographyProps) => {
  const { description } = usePurchaseOrderContext()

  if (!children && !description) {
    return null
  }

  return (
    <Typography
      variant="caption"
      color="grey600"
      data-test={PURCHASE_ORDER_DESCRIPTION_TEST_ID}
      {...props}
    >
      {children || description}
    </Typography>
  )
}
