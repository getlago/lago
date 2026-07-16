import { MappableTypeEnum, MappingTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { isDefaultMappingInMappableContext } from '~/pages/settings/integrations/common'

import { XeroIntegrationMapItemDrawerProps } from './types'

export const useXeroIntegrationTitleAndDescriptionMapping = () => {
  const { translate } = useInternationalization()

  const getTitleAndDescription = (
    dataToTest: XeroIntegrationMapItemDrawerProps | undefined,
    formType: MappableTypeEnum | MappingTypeEnum | undefined,
  ): { title: string; description: string } => {
    if (!dataToTest || !formType)
      return {
        title: '',
        description: '',
      }

    switch (formType) {
      case MappingTypeEnum.Coupon:
        return {
          title: translate('text_6630e57386f8a700a3318cc8', {
            integrationType: translate('text_6672ebb8b1b50be550eccaf8'),
          }),
          description: translate('text_6630e57386f8a700a3318cc9', {
            integrationType: translate('text_6672ebb8b1b50be550eccaf8'),
          }),
        }
      case MappingTypeEnum.CreditNote:
        return {
          title: translate('text_66461b36b4b38c006e8b5067', {
            integrationType: translate('text_6672ebb8b1b50be550eccaf8'),
          }),
          description: translate('text_66461b36b4b38c006e8b5068', {
            integrationType: translate('text_6672ebb8b1b50be550eccaf8'),
          }),
        }
      case MappingTypeEnum.FallbackItem:
        return {
          title: translate('text_6630e51df0a194013daea61f'),
          description: translate('text_6668821d94e4da4dfd8b3890', {
            integrationType: translate('text_6672ebb8b1b50be550eccaf8'),
          }),
        }
      case MappingTypeEnum.MinimumCommitment:
        return {
          title: translate('text_6668821d94e4da4dfd8b3822', {
            integrationType: translate('text_6672ebb8b1b50be550eccaf8'),
          }),
          description: translate('text_6668821d94e4da4dfd8b382e', {
            integrationType: translate('text_6672ebb8b1b50be550eccaf8'),
          }),
        }
      case MappingTypeEnum.PrepaidCredit:
        return {
          title: translate('text_6668821d94e4da4dfd8b3884', {
            integrationType: translate('text_6672ebb8b1b50be550eccaf8'),
          }),
          description: translate('text_6668821d94e4da4dfd8b389a', {
            integrationType: translate('text_6672ebb8b1b50be550eccaf8'),
          }),
        }
      case MappingTypeEnum.SubscriptionFee:
        return {
          title: translate('text_666886c73a2ea34eb2aa3e33', {
            integrationType: translate('text_6672ebb8b1b50be550eccaf8'),
          }),
          description: translate('text_666886c73a2ea34eb2aa3e34', {
            integrationType: translate('text_6672ebb8b1b50be550eccaf8'),
          }),
        }
      case MappingTypeEnum.Account:
        return {
          title: translate('text_6672ebb8b1b50be550ecca50', {
            integrationType: translate('text_6672ebb8b1b50be550eccaf8'),
          }),
          description: translate('text_6672ebb8b1b50be550ecca58', {
            integrationType: translate('text_6672ebb8b1b50be550eccaf8'),
          }),
        }
      case MappableTypeEnum.AddOn:
        return {
          title: translate('text_6668821d94e4da4dfd8b3820', {
            integrationType: translate('text_6672ebb8b1b50be550eccaf8'),
            addOnName: isDefaultMappingInMappableContext(dataToTest)
              ? dataToTest.itemMappings.default.lagoMappableName
              : '',
          }),
          description: translate('text_6668821d94e4da4dfd8b382c', {
            integrationType: translate('text_6672ebb8b1b50be550eccaf8'),
          }),
        }
      case MappableTypeEnum.BillableMetric:
        return {
          title: translate('text_6668821d94e4da4dfd8b3824', {
            integrationType: translate('text_6672ebb8b1b50be550eccaf8'),
            billableMetricName: isDefaultMappingInMappableContext(dataToTest)
              ? dataToTest.itemMappings.default.lagoMappableName
              : '',
          }),
          description: translate('text_6668821d94e4da4dfd8b3830', {
            integrationType: translate('text_6672ebb8b1b50be550eccaf8'),
          }),
        }
      default:
        return { title: '', description: '' }
    }
  }

  return {
    getTitleAndDescription,
  }
}
