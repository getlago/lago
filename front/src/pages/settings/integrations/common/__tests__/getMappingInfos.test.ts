import { IntegrationTypeEnum } from '~/generated/graphql'

import { getMappingInfos } from '../getMappingInfos'

describe('getMappingInfos', () => {
  it('should return undefined for invalid item mappings', () => {
    const invalidItemMapping = {
      externalId: 'ext-123',
      externalName: 'External Name',
    }
    const result = getMappingInfos(invalidItemMapping, IntegrationTypeEnum.Xero)

    expect(result).toBeUndefined()
  })

  it('should return correct mapping info for Xero provider', () => {
    const validItemMapping = {
      id: '123',
      externalAccountCode: 'AC-456',
      externalName: 'External Name',
    }
    const result = getMappingInfos(validItemMapping, IntegrationTypeEnum.Xero)

    expect(result).toEqual({
      id: 'AC-456',
      name: 'External Name',
    })
  })

  it('should return correct mapping info for non-Xero providers', () => {
    const validItemMapping = {
      id: '123',
      externalId: 'ext-123',
      externalName: 'External Name',
    }
    const result = getMappingInfos(validItemMapping, IntegrationTypeEnum.Netsuite)

    expect(result).toEqual({
      id: 'ext-123',
      name: 'External Name',
    })
  })

  it('should return undefined for unauthorized providers', () => {
    const validItemMapping = {
      id: '123',
      externalId: 'ext-123',
      externalName: 'External Name',
    }
    // @ts-expect-error Testing unauthorized provider
    const result = getMappingInfos(validItemMapping, IntegrationTypeEnum.Hubspot)

    expect(result).toBeUndefined()
  })
})
