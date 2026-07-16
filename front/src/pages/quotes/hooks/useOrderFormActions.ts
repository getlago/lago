import { IconName } from 'lago-design-system'
import { generatePath } from 'react-router-dom'

import { SIGN_ORDER_FORM_ROUTE, useNavigate, VOID_ORDER_FORM_ROUTE } from '~/core/router'
import { OrderFormListItemFragment, OrderFormStatusEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { usePermissions } from '~/hooks/usePermissions'
import { buildOrderFormHeader } from '~/pages/quotes/common/buildOrderFormHeader'
import { buildQuotePreviewProps } from '~/pages/quotes/common/buildQuotePreviewProps'
import { useDownloadQuotePdf } from '~/pages/quotes/common/QuotePdfProvider'

export interface OrderFormAction {
  icon: IconName
  label: string
  onAction: () => void
}

export const useOrderFormActions = () => {
  const { translate } = useInternationalization()
  const { hasPermissions } = usePermissions()
  const navigate = useNavigate()
  const { download } = useDownloadQuotePdf()
  const { intlFormatDateTimeOrgaTZ } = useOrganizationInfos()

  const getActions = (orderForm: OrderFormListItemFragment): OrderFormAction[] => {
    const actions: OrderFormAction[] = []

    // Download PDF — only when quote has content
    const version = orderForm.quote.currentVersion
    const content = version?.content

    // Sign — only for generated status, requires orderFormsSign permission
    if (orderForm.status === OrderFormStatusEnum.Generated && hasPermissions(['orderFormsSign'])) {
      actions.push({
        icon: 'writing-sign',
        label: translate('text_1781686594125upfeikkemuy'),
        onAction: () =>
          navigate(generatePath(SIGN_ORDER_FORM_ROUTE, { orderFormId: orderForm.id })),
      })
    }

    if (content) {
      const header = buildOrderFormHeader(
        orderForm,
        translate,
        (iso) => intlFormatDateTimeOrgaTZ(iso).date,
      )

      actions.push({
        icon: 'download',
        label: translate('text_17797156485850t8yms6hf7z'),
        onAction: () => {
          void download(
            buildQuotePreviewProps({
              version,
              customer: orderForm.customer,
              images: (orderForm.quote.images ?? {}) as Record<string, string>,
              header,
            }),
          ).catch(() => undefined)
        },
      })
    }

    // Void — only for generated status, requires orderFormsVoid permission
    if (orderForm.status === OrderFormStatusEnum.Generated && hasPermissions(['orderFormsVoid'])) {
      actions.push({
        icon: 'stop',
        label: translate('text_1779715648584xw9xgemkv9y'),
        onAction: () =>
          navigate(generatePath(VOID_ORDER_FORM_ROUTE, { orderFormId: orderForm.id })),
      })
    }

    return actions
  }

  return { getActions }
}
