import { useEffect, useRef } from 'react'
import { Outlet } from 'react-router-dom'

import CustomerPortalLoading from '~/components/customerPortal/common/CustomerPortalLoading'
import CustomerPortalSidebar from '~/components/customerPortal/common/CustomerPortalSidebar'
import { useCustomerPortalData } from '~/components/customerPortal/common/hooks/useCustomerPortalData'
import useCustomerPortalNavigation from '~/components/customerPortal/common/hooks/useCustomerPortalNavigation'
import SectionError from '~/components/customerPortal/common/SectionError'
import {
  LoaderCustomerInformationSection,
  LoaderInvoicesListSection,
  LoaderUsageSection,
  LoaderWalletSection,
} from '~/components/customerPortal/common/SectionLoading'
import SectionTitle from '~/components/customerPortal/common/SectionTitle'
import useCustomerPortalTranslate from '~/components/customerPortal/common/useCustomerPortalTranslate'
import { hasDefinedGQLError } from '~/core/apolloClient'
import { PremiumIntegrationTypeEnum } from '~/generated/graphql'
import { tw } from '~/styles/utils'

export const CUSTOMER_PORTAL_ERROR_STATE_TEST_ID = 'customer-portal-error-state'
export const CUSTOMER_PORTAL_LOADING_STATE_TEST_ID = 'customer-portal-loading-state'
export const CUSTOMER_PORTAL_CONTENT_STATE_TEST_ID = 'customer-portal-content-state'

const CustomerPortal = () => {
  const isInsideIframe = window.top !== window.self
  const showSidebar = !isInsideIframe

  const {
    translate,
    error: customerPortalTranslateError,
    loading: portalIsLoading,
    isUnauthenticated,
  } = useCustomerPortalTranslate()

  const portalIsError =
    isUnauthenticated ||
    (customerPortalTranslateError &&
      hasDefinedGQLError('Unauthorized', customerPortalTranslateError))

  const customerPortalContentRef = useRef<HTMLDivElement>(null)

  const { pathname } = useCustomerPortalNavigation()

  const {
    data: portalData,
    loading: portalDataLoading,
    error: portalDataError,
  } = useCustomerPortalData()

  const portalOrganization = portalData?.customerPortalOrganization

  const containerClassName = tw(
    'flex flex-col bg-white md:flex-row',
    !showSidebar && 'justify-center',
  )

  const contentContainerClassName = tw(
    'h-screen w-full overflow-y-auto bg-white p-4',
    showSidebar && 'md:p-20',
  )

  const contentInnerContainerClassName = tw(showSidebar && 'max-w-screen-lg')

  const pageContainerClassName = tw(showSidebar && 'max-w-2xl')

  const showPoweredBy = !portalOrganization?.premiumIntegrations?.includes(
    PremiumIntegrationTypeEnum.RemoveBrandingWatermark,
  )

  useEffect(() => {
    customerPortalContentRef.current?.scrollTo?.(0, 0)
  }, [pathname])

  if (portalIsError) {
    return (
      <div data-test={CUSTOMER_PORTAL_ERROR_STATE_TEST_ID} className={containerClassName}>
        {showSidebar && (
          <CustomerPortalSidebar
            organizationName={portalOrganization?.name}
            organizationLogoUrl={portalOrganization?.logoUrl}
            showPoweredBy={showPoweredBy}
            isLoading={portalDataLoading}
            isError={portalDataError}
          />
        )}

        <div className={contentContainerClassName}>
          <div className={contentInnerContainerClassName}>
            <SectionError
              customTitle={translate('text_1728546284339z3fs0oqdejs')}
              hideDescription={true}
            />
          </div>
        </div>
      </div>
    )
  }

  if (portalIsLoading) {
    return (
      <div data-test={CUSTOMER_PORTAL_LOADING_STATE_TEST_ID} className={containerClassName}>
        {showSidebar && <CustomerPortalSidebar isLoading={true} />}

        <div className={contentContainerClassName}>
          <div className={contentInnerContainerClassName}>
            <div className="flex flex-col gap-12">
              <div>
                <SectionTitle title="" loading={true} />
                <LoaderWalletSection />
              </div>
              <div>
                <SectionTitle title="" loading={true} />
                <LoaderUsageSection />
              </div>
              <div>
                <SectionTitle title="" loading={true} />
                <LoaderCustomerInformationSection />
              </div>
              <div>
                <SectionTitle title="" loading={true} />
                <LoaderInvoicesListSection />
              </div>
            </div>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div data-test={CUSTOMER_PORTAL_CONTENT_STATE_TEST_ID} className={containerClassName}>
      {showSidebar && (
        <CustomerPortalSidebar
          organizationName={portalOrganization?.name}
          organizationLogoUrl={portalOrganization?.logoUrl}
          isLoading={portalDataLoading}
          isError={portalDataError}
        />
      )}

      <div className={contentContainerClassName} ref={customerPortalContentRef}>
        <div className={contentInnerContainerClassName}>
          {portalDataLoading && <CustomerPortalLoading />}

          {!portalDataLoading && (
            <div className={pageContainerClassName}>
              <Outlet />
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

export default CustomerPortal
