import { useMemo } from 'react'

import { type ActionItem, TableColumn } from '~/components/designSystem/Table'
import { SetAsDefaultInput } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { PaymentMethodItem } from '~/hooks/customer/usePaymentMethodsList'

import { generatePaymentMethodsActions } from './actions'
import { PaymentMethodDetailsCell } from './PaymentMethodDetailsCell'
import { PaymentMethodStatusCell } from './PaymentMethodStatusCell'

interface UsePaymentMethodsTableColumnsParams {
  setPaymentMethodAsDefault: (input: SetAsDefaultInput) => Promise<void>
  onDeletePaymentMethod: (item: PaymentMethodItem) => void
}

interface UsePaymentMethodsTableColumnsReturn {
  columns: Array<TableColumn<PaymentMethodItem> | null>
  actionColumn: (item: PaymentMethodItem) => Array<ActionItem<PaymentMethodItem> | null>
}

export const usePaymentMethodsTableColumns = ({
  setPaymentMethodAsDefault,
  onDeletePaymentMethod,
}: UsePaymentMethodsTableColumnsParams): UsePaymentMethodsTableColumnsReturn => {
  const { translate } = useInternationalization()

  return useMemo(
    () => ({
      columns: [
        {
          key: 'id',
          title: translate('text_1762437511802dynl0tx20xe'),
          maxSpace: true,
          content: (item: PaymentMethodItem) => <PaymentMethodDetailsCell item={item} />,
        },
        {
          key: 'id',
          title: translate('text_63ac86d797f728a87b2f9fa7'),
          content: (item: PaymentMethodItem) => <PaymentMethodStatusCell item={item} />,
        },
      ],
      actionColumn: (item: PaymentMethodItem) =>
        generatePaymentMethodsActions({
          translate,
          setPaymentMethodAsDefault,
          onDeletePaymentMethod,
          item,
        }),
    }),
    [translate, setPaymentMethodAsDefault, onDeletePaymentMethod],
  )
}
