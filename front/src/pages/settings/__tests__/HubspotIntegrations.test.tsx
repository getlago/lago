import { cleanup, screen, waitFor } from '@testing-library/react'

import { GetHubspotIntegrationsListDocument, IntegrationTypeEnum } from '~/generated/graphql'

import {
  createIntegrationListLoadingMock,
  createIntegrationListMock,
  renderIntegrationPage,
} from './integrationTestHelpers'

import HubspotIntegrations from '../HubspotIntegrations'

jest.mock('~/components/settings/integrations/AddHubspotDialog', () => ({
  AddHubspotDialog: () => null,
}))
jest.mock('~/components/settings/integrations/DeleteHubspotIntegrationDialog', () => ({
  useDeleteHubspotIntegrationDialog: () => ({
    openDeleteHubspotIntegrationDialog: jest.fn(),
  }),
}))

describe('HubspotIntegrations', () => {
  afterEach(cleanup)

  describe('GIVEN the page is rendered with data', () => {
    it('THEN renders connection items when data is loaded', async () => {
      await renderIntegrationPage(HubspotIntegrations, {
        mocks: createIntegrationListMock(
          GetHubspotIntegrationsListDocument,
          IntegrationTypeEnum.Hubspot,
          'HubspotIntegration',
        ),
      })

      await waitFor(() => {
        expect(screen.getByText('Test Connection')).toBeInTheDocument()
        expect(screen.getByText('test-code')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the page is loading', () => {
    it('THEN shows loading skeletons while fetching', async () => {
      const { container } = await renderIntegrationPage(HubspotIntegrations, {
        mocks: createIntegrationListLoadingMock(
          GetHubspotIntegrationsListDocument,
          IntegrationTypeEnum.Hubspot,
        ),
      })

      expect(screen.queryByText('Test Connection')).not.toBeInTheDocument()
      expect(container.querySelector('.animate-pulse')).toBeInTheDocument()
    })
  })
})
