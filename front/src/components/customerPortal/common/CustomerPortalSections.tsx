import { useCustomerPortalData } from '~/components/customerPortal/common/hooks/useCustomerPortalData'
import useCustomerPortalNavigation from '~/components/customerPortal/common/hooks/useCustomerPortalNavigation'
import useCustomerPortalTranslate from '~/components/customerPortal/common/useCustomerPortalTranslate'
import PortalCustomerInfos from '~/components/customerPortal/PortalCustomerInfos'
import PortalInvoicesList from '~/components/customerPortal/PortalInvoicesList'
import UsageSection from '~/components/customerPortal/usage/UsageSection'
import WalletSection from '~/components/customerPortal/wallet/WalletSection'
import { Typography } from '~/components/designSystem/Typography'
import { PremiumIntegrationTypeEnum } from '~/generated/graphql'
import Logo from '~/public/images/logo/lago-logo-grey.svg'

export const CUSTOMER_PORTAL_SECTIONS_TEST_ID = 'customer-portal-sections'
export const CUSTOMER_PORTAL_SECTIONS_POWERED_BY_TEST_ID = 'customer-portal-sections-powered-by'

const CustomerPortalSections = () => {
  const { translate } = useCustomerPortalTranslate()

  const { data: portalData } = useCustomerPortalData()

  const { viewWallet, viewSubscription, viewEditInformation } = useCustomerPortalNavigation()

  const showPoweredBy = !portalData?.customerPortalOrganization?.premiumIntegrations?.includes(
    PremiumIntegrationTypeEnum.RemoveBrandingWatermark,
  )

  return (
    <div className="flex flex-col gap-12" data-test={CUSTOMER_PORTAL_SECTIONS_TEST_ID}>
      <WalletSection viewWallet={viewWallet} />
      <UsageSection viewSubscription={viewSubscription} />
      <PortalCustomerInfos viewEditInformation={viewEditInformation} />
      <PortalInvoicesList />

      {showPoweredBy && (
        <div
          className="my-8 flex justify-center gap-2 md:hidden"
          data-test={CUSTOMER_PORTAL_SECTIONS_POWERED_BY_TEST_ID}
        >
          <Typography variant="body" color="grey600">
            {translate('text_6419c64eace749372fc72b03')}
          </Typography>

          <Logo width="40px" />
        </div>
      )}
    </div>
  )
}

export default CustomerPortalSections
