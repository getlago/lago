import { ApolloError } from '@apollo/client'

import { LoaderSidebarOrganization } from '~/components/customerPortal/common/SectionLoading'
import useCustomerPortalTranslate from '~/components/customerPortal/common/useCustomerPortalTranslate'
import { Typography } from '~/components/designSystem/Typography'
import Logo from '~/public/images/logo/lago-logo-grey.svg'

type CustomerPortalSidebarProps = {
  organizationName?: string | null
  organizationLogoUrl?: string | null
  isLoading?: boolean
  isError?: ApolloError
  showPoweredBy?: boolean
}

const CustomerPortalSidebar = ({
  organizationName,
  organizationLogoUrl,
  isLoading,
  showPoweredBy,
}: CustomerPortalSidebarProps) => {
  const { translate } = useCustomerPortalTranslate()

  return (
    <>
      <div className="hidden h-screen w-[400px] shrink-0 flex-col gap-8 bg-grey-100 p-16 md:flex">
        {(isLoading || !!organizationLogoUrl || organizationName) && (
          <div className="flex items-center">
            {isLoading && (
              <div className="w-full">
                <LoaderSidebarOrganization />
              </div>
            )}

            {!isLoading && !!organizationLogoUrl && (
              <div className="mr-3 size-8">
                <img
                  className="size-full rounded-lg object-cover"
                  src={organizationLogoUrl}
                  alt={`${organizationName}'s logo`}
                />
              </div>
            )}

            {organizationName && <Typography variant="headline">{organizationName}</Typography>}
          </div>
        )}

        {!isLoading && (
          <Typography variant="subhead1" color="grey700">
            {translate('text_1728636271035se9pkfziyvg')}
          </Typography>
        )}

        {showPoweredBy && (
          <div className="flex items-center gap-1">
            <Typography variant="caption" color="grey600">
              {translate('text_6419c64eace749372fc72b03')}
            </Typography>

            <Logo width="40px" />
          </div>
        )}
      </div>

      <div className="mb-4 flex w-full items-center justify-center bg-grey-100 px-5 py-8 md:hidden">
        <div className="flex items-center">
          {!!organizationLogoUrl && (
            <div className="mr-4 size-8">
              <img
                className="size-full rounded-lg object-cover"
                src={organizationLogoUrl}
                alt={`${organizationName}'s logo`}
              />
            </div>
          )}
          <Typography variant="headline">{organizationName}</Typography>
        </div>
      </div>
    </>
  )
}

export default CustomerPortalSidebar
