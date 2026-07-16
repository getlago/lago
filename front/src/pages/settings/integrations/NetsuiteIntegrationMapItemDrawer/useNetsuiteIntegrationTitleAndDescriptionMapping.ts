import { MappableTypeEnum, MappingTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { isDefaultMappingInMappableContext } from '~/pages/settings/integrations/common'

import { NetsuiteIntegrationMapItemDrawerProps } from './types'

export const useNetsuiteIntegrationTitleAndDescriptionMapping = () => {
  const { translate } = useInternationalization()

  const getTitleAndDescription = (
    dataToTest: NetsuiteIntegrationMapItemDrawerProps | undefined,
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
            integrationType: translate('text_661ff6e56ef7e1b7c542b239'),
          }),
          description: translate('text_6630e57386f8a700a3318cc9', {
            integrationType: translate('text_661ff6e56ef7e1b7c542b239'),
          }),
        }
      case MappingTypeEnum.CreditNote:
        return {
          title: translate('text_66461b36b4b38c006e8b5067', {
            integrationType: translate('text_661ff6e56ef7e1b7c542b239'),
          }),
          description: translate('text_66461b36b4b38c006e8b5068', {
            integrationType: translate('text_661ff6e56ef7e1b7c542b239'),
          }),
        }
      case MappingTypeEnum.FallbackItem:
        return {
          title: translate('text_6630e51df0a194013daea61f'),
          description: translate('text_6630e51df0a194013daea620', {
            integrationType: translate('text_661ff6e56ef7e1b7c542b239'),
          }),
        }
      case MappingTypeEnum.MinimumCommitment:
        return {
          title: translate('text_6668821d94e4da4dfd8b3822', {
            integrationType: translate('text_661ff6e56ef7e1b7c542b239'),
          }),
          description: translate('text_6668821d94e4da4dfd8b382e', {
            integrationType: translate('text_661ff6e56ef7e1b7c542b239'),
          }),
        }
      case MappingTypeEnum.PrepaidCredit:
        return {
          title: translate('text_6668821d94e4da4dfd8b3884', {
            integrationType: translate('text_661ff6e56ef7e1b7c542b239'),
          }),
          description: translate('text_6668821d94e4da4dfd8b389a', {
            integrationType: translate('text_661ff6e56ef7e1b7c542b239'),
          }),
        }
      case MappingTypeEnum.Tax:
        return {
          title: translate('text_6630e560a830417bd3b119fb', {
            integrationType: translate('text_661ff6e56ef7e1b7c542b239'),
          }),
          description: translate('text_6630e560a830417bd3b119fc', {
            integrationType: translate('text_661ff6e56ef7e1b7c542b239'),
          }),
        }
      case MappingTypeEnum.SubscriptionFee:
        return {
          title: translate('text_666886c73a2ea34eb2aa3e33', {
            integrationType: translate('text_661ff6e56ef7e1b7c542b239'),
          }),
          description: translate('text_666886c73a2ea34eb2aa3e34', {
            integrationType: translate('text_661ff6e56ef7e1b7c542b239'),
          }),
        }
      case MappableTypeEnum.AddOn:
        return {
          title: translate('text_6668821d94e4da4dfd8b3820', {
            addOnName: isDefaultMappingInMappableContext(dataToTest)
              ? dataToTest.itemMappings.default.lagoMappableName
              : '',
            integrationType: translate('text_661ff6e56ef7e1b7c542b239'),
          }),
          description: translate('text_6668821d94e4da4dfd8b382c', {
            integrationType: translate('text_661ff6e56ef7e1b7c542b239'),
          }),
        }
      case MappableTypeEnum.BillableMetric:
        return {
          title: translate('text_6668821d94e4da4dfd8b3824', {
            billableMetricName: isDefaultMappingInMappableContext(dataToTest)
              ? dataToTest.itemMappings.default.lagoMappableName
              : '',
            integrationType: translate('text_661ff6e56ef7e1b7c542b239'),
          }),
          description: translate('text_6668821d94e4da4dfd8b3830', {
            integrationType: translate('text_661ff6e56ef7e1b7c542b239'),
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
