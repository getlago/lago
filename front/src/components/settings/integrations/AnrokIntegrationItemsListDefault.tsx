import { gql } from '@apollo/client'
import { RefObject } from 'react'

import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import {
  AnrokIntegrationItemsListDefaultFragment,
  IntegrationTypeEnum,
  MappingTypeEnum,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { AnrokIntegrationMapItemDrawerRef } from '~/pages/settings/integrations/AnrokIntegrationMapItemDrawer'
import {
  type IntegrationItem,
  IntegrationItemsTable,
} from '~/pages/settings/integrations/IntegrationItem'
import ErrorImage from '~/public/images/maneki/error.svg'

gql`
  fragment AnrokIntegrationItemsListDefault on CollectionMapping {
    id
    mappingType
    externalId
    externalAccountCode
    externalName
    billingEntityId
  }
`

type AnrokIntegrationItemsListDefaultProps = {
  defaultItems: AnrokIntegrationItemsListDefaultFragment[] | undefined
  hasError: boolean
  integrationId: string
  isLoading: boolean
  anrokIntegrationMapItemDrawerRef: RefObject<AnrokIntegrationMapItemDrawerRef>
}

const AnrokIntegrationItemsListDefault = ({
  defaultItems,
  hasError,
  integrationId,
  isLoading,
  anrokIntegrationMapItemDrawerRef,
}: AnrokIntegrationItemsListDefaultProps) => {
  const { translate } = useInternationalization()

  if (!isLoading && hasError) {
    return (
      <GenericPlaceholder
        title={translate('text_624451f920b6a500aab3761a')}
        subtitle={translate('text_624451f920b6a500aab3761e')}
        buttonTitle={translate('text_624451f920b6a500aab37622')}
        buttonVariant="primary"
        buttonAction={() => location.reload()}
        image={<ErrorImage width="136" height="104" />}
      />
    )
  }

  /**
   * integrationMappings is passed to each item because FetchableIntegrationItems (billing + addOns) each have their own mappings
   * while defaultItems here is the full list of mappings for all mapping types
   */
  const defaultListToDisplay: Array<IntegrationItem> = [
    {
      id: 'fallback-item',
      icon: 'box',
      label: translate('text_6630e3210c13c500cd398e98'),
      description: translate('text_6630e3210c13c500cd398e99'),
      mappingType: MappingTypeEnum.FallbackItem,
      integrationMappings: defaultItems,
    },
    {
      id: 'subscription-fee',
      icon: 'board',
      label: translate('text_6630e3210c13c500cd398ea2'),
      description: translate('text_6630e3210c13c500cd398ea3'),
      mappingType: MappingTypeEnum.SubscriptionFee,
      integrationMappings: defaultItems,
    },
    {
      id: 'minimum-commitment',
      icon: 'board',
      label: translate('text_6630e3210c13c500cd398ea5'),
      description: translate('text_6630e3210c13c500cd398ea3'),
      mappingType: MappingTypeEnum.MinimumCommitment,
      integrationMappings: defaultItems,
    },
  ]

  return (
    <IntegrationItemsTable
      integrationId={integrationId}
      integrationMapItemDrawerRef={anrokIntegrationMapItemDrawerRef}
      items={defaultListToDisplay}
      provider={IntegrationTypeEnum.Anrok}
      isLoading={isLoading}
    />
  )
}

export default AnrokIntegrationItemsListDefault
