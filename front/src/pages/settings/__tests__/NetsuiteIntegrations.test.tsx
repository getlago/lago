import { cleanup, screen, waitFor } from '@testing-library/react'

import { GetNetsuiteIntegrationsListDocument, IntegrationTypeEnum } from '~/generated/graphql'

import {
  createIntegrationListLoadingMock,
  createIntegrationListMock,
  renderIntegrationPage,
} from './integrationTestHelpers'

import NetsuiteIntegrations from '../NetsuiteIntegrations'

jest.mock('~/components/settings/integrations/AddNetsuiteDialog', () => ({
  AddNetsuiteDialog: () => null,
}))
jest.mock('~/components/settings/integrations/DeleteNetsuiteIntegrationDialog', () => ({
  useDeleteNetsuiteIntegrationDialog: () => ({ openDeleteNetsuiteIntegrationDialog: jest.fn() }),
}))

describe('NetsuiteIntegrations', () => {
  afterEach(cleanup)

  describe('GIVEN the page is rendered with data', () => {
    it('THEN renders connection items when data is loaded', async () => {
      await renderIntegrationPage(NetsuiteIntegrations, {
        mocks: createIntegrationListMock(
          GetNetsuiteIntegrationsListDocument,
          IntegrationTypeEnum.Netsuite,
          'NetsuiteIntegration',
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
      const { container } = await renderIntegrationPage(NetsuiteIntegrations, {
        mocks: createIntegrationListLoadingMock(
          GetNetsuiteIntegrationsListDocument,
          IntegrationTypeEnum.Netsuite,
        ),
      })

      expect(screen.queryByText('Test Connection')).not.toBeInTheDocument()
      expect(container.querySelector('.animate-pulse')).toBeInTheDocument()
    })
  })
})
