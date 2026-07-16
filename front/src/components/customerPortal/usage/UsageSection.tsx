import { gql } from '@apollo/client'

import SectionError from '~/components/customerPortal/common/SectionError'
import { LoaderUsageSection } from '~/components/customerPortal/common/SectionLoading'
import SectionTitle from '~/components/customerPortal/common/SectionTitle'
import TextButton from '~/components/customerPortal/common/TextButton'
import useCustomerPortalTranslate from '~/components/customerPortal/common/useCustomerPortalTranslate'
import UsageSubscriptionItem from '~/components/customerPortal/usage/UsageSubscriptionItem'
import {
  StatusTypeEnum,
  SubscriptionForPortalUsageFragmentDoc,
  useGetPortalUsageQuery,
} from '~/generated/graphql'

gql`
  query getPortalUsage($status: [StatusTypeEnum!]) {
    customerPortalSubscriptions(status: $status) {
      collection {
        id
        ...SubscriptionForPortalUsage
      }
    }
  }

  ${SubscriptionForPortalUsageFragmentDoc}
`

type PortalUsageSectionProps = {
  viewSubscription: (id: string) => void
}

const UsageSection = ({ viewSubscription }: PortalUsageSectionProps) => {
  const { translate } = useCustomerPortalTranslate()

  const {
    data: portalUsageData,
    loading: portalUsageLoading,
    error: portalUsageError,
    refetch: portalUsageRefetch,
  } = useGetPortalUsageQuery({
    variables: {
      status: [StatusTypeEnum.Active],
    },
  })

  const subscription = portalUsageData?.customerPortalSubscriptions?.collection

  const applicableTimezone =
    portalUsageData?.customerPortalSubscriptions?.collection?.[0]?.customer?.applicableTimezone

  const isLoading = portalUsageLoading
  const isError = portalUsageError

  if (!isLoading && isError) {
    return (
      <section>
        <SectionTitle title={translate('text_1728377307160ilquuusbuwq')} />

        <SectionError refresh={() => portalUsageRefetch()} />
      </section>
    )
  }

  if (!isLoading && !subscription?.length) {
    return null
  }

  return (
    <div>
      <SectionTitle title={translate('text_1728377307160ilquuusbuwq')} loading={isLoading} />

      {isLoading && <LoaderUsageSection />}

      {!isLoading && subscription?.length && (
        <div className="grid grid-cols-1 gap-x-8 gap-y-6 md:grid-cols-2">
          {subscription?.map((item) => (
            <UsageSubscriptionItem
              subscription={item}
              applicableTimezone={applicableTimezone}
              key={item.id}
            >
              <TextButton
                content={translate('text_17283773071604x345yf0jbz')}
                onClick={() => viewSubscription(item.id)}
              />
            </UsageSubscriptionItem>
          ))}
        </div>
      )}
    </div>
  )
}

export default UsageSection
