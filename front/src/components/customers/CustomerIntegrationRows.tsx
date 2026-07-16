import { gql } from '@apollo/client'
import { Icon } from 'lago-design-system'

import { LinkedPaymentProvider } from '~/components/customers/types'
import { getConnectedIntegrations } from '~/components/customers/utils'
import { Avatar, AvatarConnectorVariant, AvatarSize } from '~/components/designSystem/Avatar'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { InfoRow } from '~/components/InfoRow'
import { InlineLink } from '~/components/InlineLink'
import { PaymentProviderChip } from '~/components/PaymentProviderChip'
import {
  buildAnrokCustomerUrl,
  buildAvalaraCustomerUrl,
  buildHubspotObjectUrl,
  buildNetsuiteCustomerUrl,
  buildSalesforceUrl,
  buildStripeCustomerUrl,
  buildXeroCustomerUrl,
} from '~/core/constants/externalUrls'
import { getTargetedObjectTranslationKey } from '~/core/constants/form'
import {
  CustomerMainInfosFragment,
  ProviderPaymentMethodsEnum,
  ProviderTypeEnum,
  useIntegrationsListForCustomerMainInfosQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import Anrok from '~/public/images/anrok.svg'
import Avalara from '~/public/images/avalara.svg'
import Hubspot from '~/public/images/hubspot.svg'
import Netsuite from '~/public/images/netsuite.svg'
import Salesforce from '~/public/images/salesforce.svg'
import Xero from '~/public/images/xero.svg'

const PaymentProviderMethodTranslationsLookup: Record<ProviderPaymentMethodsEnum, string> = {
  [ProviderPaymentMethodsEnum.BacsDebit]: 'text_65e1f90471bc198c0c934d92',
  [ProviderPaymentMethodsEnum.Card]: 'text_64aeb7b998c4322918c84208',
  [ProviderPaymentMethodsEnum.Link]: 'text_6686b316b672a6e75a29eea0',
  [ProviderPaymentMethodsEnum.SepaDebit]: 'text_64aeb7b998c4322918c8420c',
  [ProviderPaymentMethodsEnum.UsBankAccount]: 'text_65e1f90471bc198c0c934d8e',
  [ProviderPaymentMethodsEnum.Boleto]: 'text_1738234109827diqh4eswleu',
  [ProviderPaymentMethodsEnum.Crypto]: 'text_17394287699017cunbdlhnhf',
  [ProviderPaymentMethodsEnum.CustomerBalance]: 'text_1739432510045wh80q1wdt4z',
}

const IntegrationsLoadingSkeleton = () => {
  return (
    <div className="mt-1 flex flex-1 flex-col gap-3">
      <Skeleton variant="text" className="w-50" />
      <Skeleton variant="text" className="w-50" />
    </div>
  )
}

gql`
  query integrationsListForCustomerMainInfos($limit: Int) {
    integrations(limit: $limit) {
      collection {
        ... on NetsuiteIntegration {
          __typename
          id
          name
          accountId
        }
        ... on AnrokIntegration {
          __typename
          id
          name
          apiKey
          externalAccountId
        }
        ... on AvalaraIntegration {
          __typename
          id
          name
          accountId
        }
        ... on XeroIntegration {
          __typename
          id
          name
        }
        ... on HubspotIntegration {
          __typename
          id
          name
          portalId
        }
        ... on SalesforceIntegration {
          __typename
          id
          name
          instanceId
        }
      }
    }
  }
`

interface Props {
  customer: CustomerMainInfosFragment
  linkedPaymentProvider: LinkedPaymentProvider
}

const CustomerIntegrationRows = ({ customer, linkedPaymentProvider }: Props) => {
  const { translate } = useInternationalization()

  const { paymentProvider: customerPaymentProvider, providerCustomer } = customer

  const { data: integrationsData, loading: integrationsLoading } =
    useIntegrationsListForCustomerMainInfosQuery({
      variables: { limit: 1000 },
      skip:
        !customer?.netsuiteCustomer &&
        !customer?.anrokCustomer &&
        !customer?.avalaraCustomer &&
        !customer?.xeroCustomer &&
        !customer?.hubspotCustomer &&
        !customer?.salesforceCustomer,
    })

  const connectedIntegrations = {
    netsuite: getConnectedIntegrations(
      integrationsData,
      customer,
      'NetsuiteIntegration',
      'netsuiteCustomer',
    ),
    xero: getConnectedIntegrations(integrationsData, customer, 'XeroIntegration', 'xeroCustomer'),
    anrok: getConnectedIntegrations(
      integrationsData,
      customer,
      'AnrokIntegration',
      'anrokCustomer',
    ),
    avalara: getConnectedIntegrations(
      integrationsData,
      customer,
      'AvalaraIntegration',
      'avalaraCustomer',
    ),
    hubspot: getConnectedIntegrations(
      integrationsData,
      customer,
      'HubspotIntegration',
      'hubspotCustomer',
    ),
    salesforce: getConnectedIntegrations(
      integrationsData,
      customer,
      'SalesforceIntegration',
      'salesforceCustomer',
    ),
  }

  const { netsuite, xero, anrok, avalara, hubspot, salesforce } = connectedIntegrations

  const customerIntegrations = [
    {
      integrationProvider: 'NetsuiteIntegration',
      canRender: !!customer?.netsuiteCustomer?.integrationId && !!netsuite?.id,
      label: translate('text_66423cad72bbad009f2f568f'),
      additionalLabel: '',
      buildExternalUrl: () => {
        if (!netsuite?.accountId || !customer?.netsuiteCustomer?.externalCustomerId) {
          return ''
        }

        return buildNetsuiteCustomerUrl(
          netsuite.accountId,
          customer.netsuiteCustomer.externalCustomerId,
        )
      },
      integrationName: netsuite?.name,
      integrationIcon: {
        icon: <Netsuite />,
        variant: 'connector-full' as AvatarConnectorVariant,
        size: 'small' as AvatarSize,
      },
      externalCustomerId: customer?.netsuiteCustomer?.externalCustomerId,
    },
    {
      integrationProvider: 'XeroIntegration',
      canRender: !!customer?.xeroCustomer?.integrationId && !!xero?.id,
      label: translate('text_66423cad72bbad009f2f568f'),
      additionalLabel: '',
      buildExternalUrl: () => {
        if (!customer?.xeroCustomer?.externalCustomerId) {
          return ''
        }

        return buildXeroCustomerUrl(customer.xeroCustomer.externalCustomerId)
      },
      integrationName: xero?.name,
      integrationIcon: {
        icon: <Xero />,
        variant: 'connector-full' as AvatarConnectorVariant,
        size: 'small' as AvatarSize,
      },
      externalCustomerId: customer?.xeroCustomer?.externalCustomerId,
    },
    {
      integrationProvider: 'AnrokIntegration',
      canRender: !!customer?.anrokCustomer?.integrationId && !!anrok?.id,
      label: translate('text_6668821d94e4da4dfd8b3840'),
      additionalLabel: '',
      buildExternalUrl: () => {
        if (!anrok?.externalAccountId || !customer?.anrokCustomer?.externalCustomerId) {
          return ''
        }

        return buildAnrokCustomerUrl(
          anrok.externalAccountId,
          customer.anrokCustomer.externalCustomerId,
        )
      },
      integrationName: anrok?.name,
      integrationIcon: {
        icon: <Anrok />,
        variant: 'connector-full' as AvatarConnectorVariant,
        size: 'small' as AvatarSize,
      },
      externalCustomerId: customer?.anrokCustomer?.externalCustomerId,
    },
    {
      integrationProvider: 'AvalaraIntegration',
      canRender: !!customer?.avalaraCustomer?.integrationId && !!avalara?.id,
      label: translate('text_6668821d94e4da4dfd8b3840'),
      additionalLabel: '',
      buildExternalUrl: () => {
        if (!customer?.avalaraCustomer?.externalCustomerId) {
          return ''
        }

        return buildAvalaraCustomerUrl(customer.avalaraCustomer.externalCustomerId)
      },
      integrationName: avalara?.name,
      integrationIcon: {
        icon: <Avalara />,
        variant: 'connector-full' as AvatarConnectorVariant,
        size: 'small' as AvatarSize,
      },
      externalCustomerId: customer?.avalaraCustomer?.externalCustomerId,
    },
    {
      integrationProvider: 'HubspotIntegration',
      canRender:
        !!hubspot?.id &&
        customer?.hubspotCustomer?.integrationId &&
        customer?.hubspotCustomer.targetedObject,
      label: translate('text_1728658962985xpfdvl5ru8a'),
      additionalLabel: customer?.hubspotCustomer?.targetedObject
        ? translate(getTargetedObjectTranslationKey[customer.hubspotCustomer.targetedObject])
        : '',
      buildExternalUrl: () => {
        if (
          !hubspot?.portalId ||
          !customer?.hubspotCustomer?.externalCustomerId ||
          !customer?.hubspotCustomer.targetedObject
        ) {
          return ''
        }

        return buildHubspotObjectUrl({
          portalId: hubspot.portalId,
          objectId: customer?.hubspotCustomer?.externalCustomerId,
          targetedObject: customer?.hubspotCustomer.targetedObject,
        })
      },
      integrationName: hubspot?.name,
      integrationIcon: {
        icon: <Hubspot />,
        variant: 'connector' as AvatarConnectorVariant,
        size: 'small' as AvatarSize,
      },
      externalCustomerId: customer?.hubspotCustomer?.externalCustomerId,
    },
    {
      integrationProvider: 'SalesforceIntegration',
      canRender:
        !!salesforce?.id &&
        customer?.salesforceCustomer?.externalCustomerId &&
        customer?.salesforceCustomer?.integrationId,
      label: translate('text_1728658962985xpfdvl5ru8a'),
      additionalLabel: '',
      buildExternalUrl: () => {
        if (!salesforce?.instanceId || !customer?.salesforceCustomer?.externalCustomerId) {
          return ''
        }

        return buildSalesforceUrl({
          instanceId: salesforce.instanceId,
          externalCustomerId: customer.salesforceCustomer.externalCustomerId,
        })
      },
      integrationName: salesforce?.name,
      integrationIcon: {
        icon: <Salesforce />,
        variant: 'connector-full' as AvatarConnectorVariant,
        size: 'small' as AvatarSize,
      },
      externalCustomerId: customer?.salesforceCustomer?.externalCustomerId,
    },
  ]

  return (
    <>
      {!!customerPaymentProvider && !!linkedPaymentProvider?.name && (
        <InfoRow>
          <Typography variant="caption">{translate('text_62b1edddbf5f461ab9712795')}</Typography>
          <div>
            <div className="flex flex-row" data-test={linkedPaymentProvider?.name}>
              <PaymentProviderChip
                paymentProvider={customerPaymentProvider}
                label={linkedPaymentProvider?.name}
              />
              {!!providerCustomer?.providerCustomerId && (
                <>
                  {customerPaymentProvider === ProviderTypeEnum?.Stripe ? (
                    <InlineLink
                      target="_blank"
                      rel="noopener noreferrer"
                      to={buildStripeCustomerUrl(providerCustomer?.providerCustomerId)}
                    >
                      <Typography className="flex items-center gap-1" color="primary600">
                        {providerCustomer?.providerCustomerId} <Icon name="outside" />
                      </Typography>
                    </InlineLink>
                  ) : (
                    <Typography color="textSecondary">
                      {providerCustomer?.providerCustomerId}
                    </Typography>
                  )}
                </>
              )}
            </div>
            {customerPaymentProvider === ProviderTypeEnum?.Stripe &&
              !!providerCustomer?.providerPaymentMethods?.length && (
                <Typography color="grey600">
                  {providerCustomer?.providerPaymentMethods
                    ?.map((method) => translate(PaymentProviderMethodTranslationsLookup[method]))
                    .join(', ')}
                </Typography>
              )}
          </div>
        </InfoRow>
      )}

      {customerIntegrations.length > 0 &&
        customerIntegrations.map(
          (
            {
              integrationProvider,
              canRender,
              label,
              additionalLabel,
              buildExternalUrl,
              integrationName,
              integrationIcon,
              externalCustomerId,
            },
            i,
          ) => {
            if (!canRender) return null
            const externalLink = buildExternalUrl()

            return (
              <InfoRow key={`${integrationProvider}-${i}`}>
                <Typography variant="caption">{label}</Typography>

                <div data-test={integrationProvider}>
                  {integrationsLoading && <IntegrationsLoadingSkeleton />}
                  {!integrationsLoading && (
                    <div className="flex flex-row">
                      <div className="flex flex-row items-center gap-2">
                        <Avatar variant={integrationIcon.variant} size={integrationIcon.size}>
                          {integrationIcon.icon}
                        </Avatar>
                        <Typography color="grey700">{integrationName}</Typography>
                      </div>
                      {additionalLabel && (
                        <Typography className="ml-2" variant="body" color="grey700">
                          {additionalLabel}
                        </Typography>
                      )}
                      {externalLink && (
                        <InlineLink
                          target="_blank"
                          rel="noopener noreferrer"
                          to={externalLink}
                          data-test="external-integration-link"
                        >
                          <Typography className="flex items-center gap-1" color="primary600">
                            {externalCustomerId} <Icon name="outside" />
                          </Typography>
                        </InlineLink>
                      )}
                    </div>
                  )}
                </div>
              </InfoRow>
            )
          },
        )}
    </>
  )
}

export { CustomerIntegrationRows }
