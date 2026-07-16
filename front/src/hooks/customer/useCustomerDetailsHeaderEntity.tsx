import { StatusType } from '~/components/designSystem/Status'
import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import { MainHeaderEntityConfig } from '~/components/MainHeader/types'
import { CustomerAccountTypeEnum, CustomerDetailsFragment } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

interface UseCustomerDetailsHeaderEntityParams {
  customer: CustomerDetailsFragment | undefined | null
  loading?: boolean
}

export function useCustomerDetailsHeaderEntity({
  customer,
  loading,
}: UseCustomerDetailsHeaderEntityParams): MainHeaderEntityConfig | undefined {
  const { translate } = useInternationalization()

  if (!customer && loading) {
    return {
      viewName: '',
      viewNameLoading: true,
      metadataLoading: true,
    }
  }

  if (!customer) return undefined

  const customerName = customer.displayName
  const isPartner = customer.accountType === CustomerAccountTypeEnum.Partner

  return {
    viewName: customerName || translate('text_62f272a7a60b4d7fadad911a'),
    metadata: customer.externalId ? (
      <TypographyWithCopy>{customer.externalId}</TypographyWithCopy>
    ) : undefined,
    badges: isPartner
      ? [{ label: translate('text_1738322099641hkzihmx9qyw'), type: StatusType.default }]
      : undefined,
  }
}
