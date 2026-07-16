import { gql } from '@apollo/client'
import { Icon } from 'lago-design-system'
import { FC } from 'react'
import { useParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { envGlobalVar } from '~/core/apolloClient'
import {
  buildAnrokCreditNoteUrl,
  buildAvalaraObjectId,
  buildNetsuiteCreditNoteUrl,
  buildXeroCreditNoteUrl,
} from '~/core/constants/externalUrls'
import { AppEnvEnum } from '~/core/constants/globalTypes'
import { Link } from '~/core/router'
import { getConnectedIntegration } from '~/core/utils/integrations'
import {
  AnrokIntegration,
  AvalaraIntegration,
  NetsuiteIntegration,
  useGetCreditNoteForDetailsExternalSyncQuery,
  useGetIntegrationsListForCreditNoteDetailsExternalSyncQuery,
  XeroIntegration,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

const { appEnv } = envGlobalVar()

gql`
  fragment CustomerForCreditNoteDetailsExternalSync on Customer {
    anrokCustomer {
      id
      integrationId
      externalAccountId
    }
    avalaraCustomer {
      id
      integrationId
    }
    netsuiteCustomer {
      id
      integrationId
    }
    xeroCustomer {
      id
      integrationId
    }
  }

  query getCreditNoteForDetailsExternalSync($id: ID!) {
    creditNote(id: $id) {
      id
      taxProviderId
      taxProviderSyncable
      externalIntegrationId
      customer {
        ...CustomerForCreditNoteDetailsExternalSync
      }
    }
  }

  query getIntegrationsListForCreditNoteDetailsExternalSync($limit: Int) {
    integrations(limit: $limit) {
      collection {
        ... on AnrokIntegration {
          __typename
          id
        }
        ... on AvalaraIntegration {
          __typename
          id
          accountId
          companyId
        }
        ... on NetsuiteIntegration {
          __typename
          id
          accountId
          name
        }
        ... on XeroIntegration {
          __typename
          id
        }
      }
    }
  }
`

const OverviewLine: FC<
  | { title: string; link: string; id: string; onClick?: never; label?: never; warning?: never }
  | {
      title: string
      onClick: () => void
      label: string
      link?: never
      id?: never
      warning?: string
    }
> = ({ title, link, id, onClick, label, warning }) => {
  return (
    <div className="flex items-start gap-2">
      <Typography variant="caption" color="grey600" noWrap className="min-w-58">
        {title}
      </Typography>

      {onClick && (
        <div className="flex items-center gap-2">
          <Icon name="warning-filled" color="warning" />
          <Typography variant="body">{warning}</Typography>
          <Typography variant="body">•</Typography>
          <Button variant="inline" onClick={onClick}>
            {label}
          </Button>
        </div>
      )}
      {link && (
        <Link
          className="w-fit line-break-anywhere visited:text-blue hover:no-underline"
          target="_blank"
          rel="noopener noreferrer"
          to={link}
        >
          <Typography variant="body" className="flex items-center gap-1 text-blue">
            {id} <Icon name="outside" />
          </Typography>
        </Link>
      )}
    </div>
  )
}

interface CreditNoteDetailsExternalSyncProps {
  retryTaxSync: () => Promise<void>
}

export const CreditNoteDetailsExternalSync: FC<CreditNoteDetailsExternalSyncProps> = ({
  retryTaxSync,
}) => {
  const { customerId, creditNoteId } = useParams()
  const { translate } = useInternationalization()

  const { data } = useGetCreditNoteForDetailsExternalSyncQuery({
    variables: { id: creditNoteId as string },
    skip: !creditNoteId || !customerId,
  })

  const creditNote = data?.creditNote
  const customer = creditNote?.customer

  const hasCustomerIntegration =
    customer?.anrokCustomer?.integrationId ||
    customer?.avalaraCustomer?.id ||
    customer?.netsuiteCustomer?.integrationId ||
    customer?.xeroCustomer?.integrationId

  const { data: integrationsData } = useGetIntegrationsListForCreditNoteDetailsExternalSyncQuery({
    variables: { limit: 1000 },
    skip: !hasCustomerIntegration,
  })

  const connectedNetsuiteIntegration = getConnectedIntegration<NetsuiteIntegration>(
    integrationsData?.integrations?.collection,
    'NetsuiteIntegration',
    customer?.netsuiteCustomer?.integrationId,
  )

  const connectedAnrokIntegration = getConnectedIntegration<AnrokIntegration>(
    integrationsData?.integrations?.collection,
    'AnrokIntegration',
    customer?.anrokCustomer?.integrationId,
  )

  const connectedXeroIntegration = getConnectedIntegration<XeroIntegration>(
    integrationsData?.integrations?.collection,
    'XeroIntegration',
    customer?.xeroCustomer?.integrationId,
  )

  const connectedAvalaraIntegration = getConnectedIntegration<AvalaraIntegration>(
    integrationsData?.integrations?.collection,
    'AvalaraIntegration',
    customer?.avalaraCustomer?.integrationId,
  )

  const hasIntegration = {
    netsuite:
      !!connectedNetsuiteIntegration &&
      !!customer?.netsuiteCustomer?.integrationId &&
      !!creditNote?.externalIntegrationId,
    xero:
      !!connectedXeroIntegration &&
      !!customer?.xeroCustomer?.integrationId &&
      !!creditNote?.externalIntegrationId,
    anrok:
      !!connectedAnrokIntegration &&
      !!customer?.anrokCustomer?.integrationId &&
      (!!creditNote?.taxProviderId || !!creditNote?.taxProviderSyncable),
    avalara:
      !!connectedAvalaraIntegration &&
      !!customer?.avalaraCustomer?.id &&
      (!!creditNote?.taxProviderId || !!creditNote?.taxProviderSyncable),
  }

  return (
    <div>
      <Typography variant="subhead1" className="mb-6 mt-8">
        {translate('text_6650b36fc702a4014c878996')}
      </Typography>
      {hasIntegration.netsuite && (
        <OverviewLine
          title={translate('text_6684044e95fa220048a145a7')}
          link={buildNetsuiteCreditNoteUrl(
            connectedNetsuiteIntegration?.accountId,
            creditNote?.externalIntegrationId,
          )}
          id={creditNote?.externalIntegrationId ?? ''}
        />
      )}
      {hasIntegration.xero && (
        <OverviewLine
          title={translate('text_66911ce41415f40090d053ce')}
          link={buildXeroCreditNoteUrl(creditNote?.externalIntegrationId)}
          id={creditNote?.externalIntegrationId ?? ''}
        />
      )}
      {hasIntegration.anrok && (
        <div className="flex flex-col gap-1">
          {!!creditNote?.taxProviderId && (
            <OverviewLine
              title={translate('text_1727068146263345gopo39sm')}
              link={buildAnrokCreditNoteUrl(
                customer?.anrokCustomer?.externalAccountId,
                creditNote?.taxProviderId,
              )}
              id={creditNote?.taxProviderId ?? ''}
            />
          )}
          {!!creditNote?.taxProviderSyncable && (
            <OverviewLine
              title={translate('text_1727068146263345gopo39sm')}
              warning={translate('text_1727068146263ztoat7i901x')}
              label={translate('text_17270681462632d46dh3r1vu')}
              onClick={async () => {
                await retryTaxSync()
              }}
            />
          )}
        </div>
      )}
      {hasIntegration.avalara && (
        <div className="flex flex-col gap-1">
          {!!creditNote?.taxProviderId && (
            <OverviewLine
              title={translate('text_1747408519913t2tehiclc5q')}
              link={buildAvalaraObjectId({
                accountId: connectedAvalaraIntegration?.accountId,
                companyId: connectedAvalaraIntegration?.companyId || '',
                objectId: creditNote?.taxProviderId,
                isSandbox: appEnv !== AppEnvEnum.production,
              })}
              id={creditNote?.taxProviderId}
            />
          )}
          {!!creditNote?.taxProviderSyncable && (
            <OverviewLine
              title={translate('text_1747408519913t2tehiclc5q')}
              warning={translate('text_1727068146263ztoat7i901x')}
              label={translate('text_17270681462632d46dh3r1vu')}
              onClick={async () => {
                await retryTaxSync()
              }}
            />
          )}
        </div>
      )}
    </div>
  )
}
