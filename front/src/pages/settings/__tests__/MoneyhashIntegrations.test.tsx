import { cleanup, screen, waitFor } from '@testing-library/react'

import { GetMoneyhashIntegrationsListDocument, ProviderTypeEnum } from '~/generated/graphql'

import {
  createPaymentProviderListLoadingMock,
  createPaymentProviderListMock,
  renderIntegrationPage,
} from './integrationTestHelpers'

import MoneyhashIntegrations from '../MoneyhashIntegrations'

jest.mock('~/components/settings/integrations/AddMoneyhashDialog', () => ({
  AddMoneyhashDialog: () => null,
}))
jest.mock('~/components/settings/integrations/DeleteMoneyhashIntegrationDialog', () => ({
  useDeleteMoneyhashIntegrationDialog: () => ({
    openDeleteMoneyhashIntegrationDialog: jest.fn(),
  }),
}))
jest.mock('~/components/settings/integrations/AddEditDeleteSuccessRedirectUrlDialog', () => ({
  AddEditDeleteSuccessRedirectUrlDialog: () => null,
}))

describe('MoneyhashIntegrations', () => {
  afterEach(cleanup)

  describe('GIVEN the page is rendered with data', () => {
    it('THEN renders connection items when data is loaded', async () => {
      await renderIntegrationPage(MoneyhashIntegrations, {
        mocks: createPaymentProviderListMock(
          GetMoneyhashIntegrationsListDocument,
          ProviderTypeEnum.Moneyhash,
          'MoneyhashProvider',
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
      const { container } = await renderIntegrationPage(MoneyhashIntegrations, {
        mocks: createPaymentProviderListLoadingMock(
          GetMoneyhashIntegrationsListDocument,
          ProviderTypeEnum.Moneyhash,
        ),
      })

      expect(screen.queryByText('Test Connection')).not.toBeInTheDocument()
      expect(container.querySelector('.animate-pulse')).toBeInTheDocument()
    })
  })
})
