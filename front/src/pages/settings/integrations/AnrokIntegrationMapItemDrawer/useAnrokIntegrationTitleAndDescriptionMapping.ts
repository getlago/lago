import { MappableTypeEnum, MappingTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { isDefaultMappingInMappableContext } from '~/pages/settings/integrations/common'

import { AnrokIntegrationMapItemDrawerProps } from './types'

export const useAnrokIntegrationTitleAndDescriptionMapping = () => {
  const { translate } = useInternationalization()

  const getTitleAndDescription = (
    dataToTest: AnrokIntegrationMapItemDrawerProps | undefined,
    formType: MappableTypeEnum | MappingTypeEnum | undefined,
  ): { title: string; description: string } => {
    if (!dataToTest || !formType)
      return {
        title: '',
        description: '',
      }

    switch (formType) {
      case MappingTypeEnum.FallbackItem:
        return {
          title: translate('text_6630e51df0a194013daea61f'),
          description: translate('text_6668821d94e4da4dfd8b3890', {
            integrationType: translate('text_6668821d94e4da4dfd8b3834'),
          }),
        }
      case MappingTypeEnum.MinimumCommitment:
        return {
          title: translate('text_6668821d94e4da4dfd8b3822', {
            integrationType: translate('text_6668821d94e4da4dfd8b3834'),
          }),
          description: translate('text_6668821d94e4da4dfd8b382e', {
            integrationType: translate('text_6668821d94e4da4dfd8b3834'),
          }),
        }
      case MappingTypeEnum.PrepaidCredit:
        return {
          title: translate('text_6668821d94e4da4dfd8b3884', {
            integrationType: translate('text_6668821d94e4da4dfd8b3834'),
          }),
          description: translate('text_6668821d94e4da4dfd8b389a', {
            integrationType: translate('text_6668821d94e4da4dfd8b3834'),
          }),
        }
      case MappingTypeEnum.SubscriptionFee:
        return {
          title: translate('text_666886c73a2ea34eb2aa3e33', {
            integrationType: translate('text_6668821d94e4da4dfd8b3834'),
          }),
          description: translate('text_666886c73a2ea34eb2aa3e34', {
            integrationType: translate('text_6668821d94e4da4dfd8b3834'),
          }),
        }
      case MappableTypeEnum.AddOn:
        return {
          title: translate('text_6668821d94e4da4dfd8b3820', {
            addOnName: isDefaultMappingInMappableContext(dataToTest)
              ? dataToTest.itemMappings.default.lagoMappableName
              : '',
            integrationType: translate('text_6668821d94e4da4dfd8b3834'),
          }),
          description: translate('text_6668821d94e4da4dfd8b382c', {
            integrationType: translate('text_6668821d94e4da4dfd8b3834'),
          }),
        }
      case MappableTypeEnum.BillableMetric:
        return {
          title: translate('text_6668821d94e4da4dfd8b3824', {
            billableMetricName: isDefaultMappingInMappableContext(dataToTest)
              ? dataToTest.itemMappings.default.lagoMappableName
              : '',
            integrationType: translate('text_6668821d94e4da4dfd8b3834'),
          }),
          description: translate('text_6668821d94e4da4dfd8b3830', {
            integrationType: translate('text_6668821d94e4da4dfd8b3834'),
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
