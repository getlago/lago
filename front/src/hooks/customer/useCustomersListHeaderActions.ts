import { CREATE_CUSTOMER_DATA_TEST } from '~/components/customers/utils/dataTestConstants'
import { MainHeaderAction } from '~/components/MainHeader/types'
import { CREATE_CUSTOMER_ROUTE, useNavigate } from '~/core/router'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { usePermissions } from '~/hooks/usePermissions'

export function useCustomersListHeaderActions(): MainHeaderAction[] {
  const { translate } = useInternationalization()
  const { hasPermissions } = usePermissions()
  const navigate = useNavigate()

  if (!hasPermissions(['customersCreate'])) return []

  return [
    {
      type: 'action',
      label: translate('text_1734452833961s338w0x3b4s'),
      variant: 'primary',
      onClick: () => navigate(CREATE_CUSTOMER_ROUTE),
      dataTest: CREATE_CUSTOMER_DATA_TEST,
    },
  ]
}
