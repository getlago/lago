import { cleanup, screen, waitFor } from '@testing-library/react'

import { GetSalesforceIntegrationsListDocument, IntegrationTypeEnum } from '~/generated/graphql'

import {
  createIntegrationListLoadingMock,
  createIntegrationListMock,
  renderIntegrationPage,
} from './integrationTestHelpers'

import SalesforceIntegrations from '../SalesforceIntegrations'

jest.mock('~/components/settings/integrations/AddSalesforceDialog', () => ({
  AddSalesforceDialog: () => null,
}))
jest.mock('~/components/settings/integrations/DeleteSalesforceIntegrationDialog', () => ({
  useDeleteSalesforceIntegrationDialog: () => ({
    openDeleteSalesforceIntegrationDialog: jest.fn(),
  }),
}))

describe('SalesforceIntegrations', () => {
  afterEach(cleanup)

  describe('GIVEN the page is rendered with data', () => {
    it('THEN renders connection items when data is loaded', async () => {
      await renderIntegrationPage(SalesforceIntegrations, {
        mocks: createIntegrationListMock(
          GetSalesforceIntegrationsListDocument,
          IntegrationTypeEnum.Salesforce,
          'SalesforceIntegration',
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
      const { container } = await renderIntegrationPage(SalesforceIntegrations, {
        mocks: createIntegrationListLoadingMock(
          GetSalesforceIntegrationsListDocument,
          IntegrationTypeEnum.Salesforce,
        ),
      })

      expect(screen.queryByText('Test Connection')).not.toBeInTheDocument()
      expect(container.querySelector('.animate-pulse')).toBeInTheDocument()
    })
  })
})
