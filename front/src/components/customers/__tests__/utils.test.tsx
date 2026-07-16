import { getConnectedIntegrations } from '../utils'

describe('getConnectedIntegrations', () => {
  it('should return undefined if data is undefined', () => {
    const result = getConnectedIntegrations(undefined, {}, 'SomeType', 'someKey')

    expect(result).toBeUndefined()
  })

  it('should return undefined if customerKey does not exist in customer', () => {
    const data = {
      integrations: { collection: [] },
    }
    const customer = {}

    const result = getConnectedIntegrations(data, customer, 'SomeType', 'nonExistentKey')

    expect(result).toBeUndefined()
  })

  it('should return the correct integration if it matches typename and id', () => {
    const data = {
      integrations: {
        collection: [
          { __typename: 'AvalaraIntegration', id: 'integration-1' },
          { __typename: 'SalesforceIntegration', id: 'integration-2' },
        ],
      },
    }

    const customer = {
      someKey: { integrationId: 'integration-1' },
    }

    const result = getConnectedIntegrations(data, customer, 'AvalaraIntegration', 'someKey')

    expect(result).toEqual({ __typename: 'AvalaraIntegration', id: 'integration-1' })
  })

  it('should return undefined if no integration matches the id', () => {
    const data = {
      integrations: {
        collection: [{ __typename: 'HubspotIntegration', id: 'integration-1' }],
      },
    }

    const customer = {
      someKey: { integrationId: 'non-existent-id' },
    }

    const result = getConnectedIntegrations(data, customer, 'SomeType', 'someKey')

    expect(result).toBeUndefined()
  })
})
