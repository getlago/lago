import { useCustomerPortalData } from '~/components/customerPortal/common/hooks/useCustomerPortalData'
import { Locale, LocaleEnum } from '~/core/translations'
import { useContextualLocale } from '~/hooks/core/useContextualLocale'

const useCustomerPortalTranslate = () => {
  const { data, error, loading } = useCustomerPortalData()

  const documentLocale =
    (data?.customerPortalUser?.billingConfiguration?.documentLocale as Locale) ||
    (data?.customerPortalUser?.billingEntityBillingConfiguration?.documentLocale as Locale) ||
    'en'

  const { translateWithContextualLocal: translate } = useContextualLocale(documentLocale)
  const isUnauthenticated = !loading && data?.customerPortalUser === null

  return {
    translate,
    documentLocale: documentLocale as LocaleEnum,
    error,
    loading,
    isUnauthenticated,
  }
}

export default useCustomerPortalTranslate
