import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { DestroyPaymentMethodInput } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { PaymentMethodItem } from '~/hooks/customer/usePaymentMethodsList'

type DeletePaymentMethodDialogInfos = {
  paymentMethod: PaymentMethodItem
  onConfirm: (input: DestroyPaymentMethodInput) => Promise<void>
}

export const useDeletePaymentMethodDialog = (): {
  openDeletePaymentMethodDialog: (infos: DeletePaymentMethodDialogInfos) => void
} => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()

  const openDeletePaymentMethodDialog = (infos: DeletePaymentMethodDialogInfos): void => {
    centralizedDialog.open({
      title: translate('text_1762437511802sg9jrl46lkb'),
      description: translate('text_17625350067233oa8biywazm'),
      actionText: translate('text_1762437511802sg9jrl46lkb'),
      colorVariant: 'danger',
      onAction: async () => {
        await infos.onConfirm({ id: infos.paymentMethod.id })
      },
    })
  }

  return { openDeletePaymentMethodDialog }
}
