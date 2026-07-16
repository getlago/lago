import { cleanup, screen, waitFor } from '@testing-library/react'

import { GetAnrokIntegrationsListDocument, IntegrationTypeEnum } from '~/generated/graphql'

import {
  createIntegrationListLoadingMock,
  createIntegrationListMock,
  renderIntegrationPage,
} from './integrationTestHelpers'

import AnrokIntegrations from '../AnrokIntegrations'

jest.mock('~/components/settings/integrations/AddAnrokDialog', () => ({
  AddAnrokDialog: () => null,
}))
jest.mock('~/components/settings/integrations/DeleteAnrokIntegrationDialog', () => ({
  useDeleteAnrokIntegrationDialog: () => ({ openDeleteAnrokIntegrationDialog: jest.fn() }),
}))

describe('AnrokIntegrations', () => {
  afterEach(cleanup)

  describe('GIVEN the page is rendered with data', () => {
    it('THEN renders connection items when data is loaded', async () => {
      await renderIntegrationPage(AnrokIntegrations, {
        mocks: createIntegrationListMock(
          GetAnrokIntegrationsListDocument,
          IntegrationTypeEnum.Anrok,
          'AnrokIntegration',
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
      const { container } = await renderIntegrationPage(AnrokIntegrations, {
        mocks: createIntegrationListLoadingMock(
          GetAnrokIntegrationsListDocument,
          IntegrationTypeEnum.Anrok,
        ),
      })

      expect(screen.queryByText('Test Connection')).not.toBeInTheDocument()
      expect(container.querySelector('.animate-pulse')).toBeInTheDocument()
    })
  })
})
