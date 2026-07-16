import { cleanup, screen, waitFor } from '@testing-library/react'

import { GetXeroIntegrationsListDocument, IntegrationTypeEnum } from '~/generated/graphql'

import {
  createIntegrationListLoadingMock,
  createIntegrationListMock,
  renderIntegrationPage,
} from './integrationTestHelpers'

import XeroIntegrations from '../XeroIntegrations'

jest.mock('@nangohq/frontend', () => ({
  __esModule: true,
  default: jest.fn(),
}))
jest.mock('~/components/settings/integrations/AddXeroDialog', () => ({
  AddXeroDialog: () => null,
}))
jest.mock('~/components/settings/integrations/DeleteXeroIntegrationDialog', () => ({
  useDeleteXeroIntegrationDialog: () => ({ openDeleteXeroIntegrationDialog: jest.fn() }),
}))

describe('XeroIntegrations', () => {
  afterEach(cleanup)

  describe('GIVEN the page is rendered with data', () => {
    it('THEN renders connection items when data is loaded', async () => {
      await renderIntegrationPage(XeroIntegrations, {
        mocks: createIntegrationListMock(
          GetXeroIntegrationsListDocument,
          IntegrationTypeEnum.Xero,
          'XeroIntegration',
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
      const { container } = await renderIntegrationPage(XeroIntegrations, {
        mocks: createIntegrationListLoadingMock(
          GetXeroIntegrationsListDocument,
          IntegrationTypeEnum.Xero,
        ),
      })

      expect(screen.queryByText('Test Connection')).not.toBeInTheDocument()
      expect(container.querySelector('.animate-pulse')).toBeInTheDocument()
    })
  })
})
