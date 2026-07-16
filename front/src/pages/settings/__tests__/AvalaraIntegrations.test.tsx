import { cleanup, screen, waitFor } from '@testing-library/react'

import { GetAvalaraIntegrationsListDocument, IntegrationTypeEnum } from '~/generated/graphql'

import {
  createIntegrationListLoadingMock,
  createIntegrationListMock,
  renderIntegrationPage,
} from './integrationTestHelpers'

import AvalaraIntegrations from '../AvalaraIntegrations'

jest.mock('~/components/settings/integrations/AddAvalaraDialog', () => ({
  AddAvalaraDialog: () => null,
}))
jest.mock('~/components/settings/integrations/DeleteAvalaraIntegrationDialog', () => ({
  useDeleteAvalaraIntegrationDialog: () => ({
    openDeleteAvalaraIntegrationDialog: jest.fn(),
  }),
}))

describe('AvalaraIntegrations', () => {
  afterEach(cleanup)

  describe('GIVEN the page is rendered with data', () => {
    it('THEN renders connection items when data is loaded', async () => {
      await renderIntegrationPage(AvalaraIntegrations, {
        mocks: createIntegrationListMock(
          GetAvalaraIntegrationsListDocument,
          IntegrationTypeEnum.Avalara,
          'AvalaraIntegration',
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
      const { container } = await renderIntegrationPage(AvalaraIntegrations, {
        mocks: createIntegrationListLoadingMock(
          GetAvalaraIntegrationsListDocument,
          IntegrationTypeEnum.Avalara,
        ),
      })

      expect(screen.queryByText('Test Connection')).not.toBeInTheDocument()
      expect(container.querySelector('.animate-pulse')).toBeInTheDocument()
    })
  })
})
