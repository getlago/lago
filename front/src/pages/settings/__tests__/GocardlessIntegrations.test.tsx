import { cleanup, screen, waitFor } from '@testing-library/react'

import { GetGocardlessIntegrationsListDocument, ProviderTypeEnum } from '~/generated/graphql'

import {
  createPaymentProviderListLoadingMock,
  createPaymentProviderListMock,
  renderIntegrationPage,
} from './integrationTestHelpers'

import GocardlessIntegrations from '../GocardlessIntegrations'

jest.mock('~/components/settings/integrations/AddGocardlessDialog', () => ({
  AddGocardlessDialog: () => null,
}))
jest.mock('~/components/settings/integrations/DeleteGocardlessIntegrationDialog', () => ({
  useDeleteGocardlessIntegrationDialog: () => ({
    openDeleteGocardlessIntegrationDialog: jest.fn(),
  }),
}))
jest.mock('~/components/settings/integrations/AddEditDeleteSuccessRedirectUrlDialog', () => ({
  AddEditDeleteSuccessRedirectUrlDialog: () => null,
}))

describe('GocardlessIntegrations', () => {
  afterEach(cleanup)

  describe('GIVEN the page is rendered with data', () => {
    it('THEN renders connection items when data is loaded', async () => {
      await renderIntegrationPage(GocardlessIntegrations, {
        mocks: createPaymentProviderListMock(
          GetGocardlessIntegrationsListDocument,
          ProviderTypeEnum.Gocardless,
          'GocardlessProvider',
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
      const { container } = await renderIntegrationPage(GocardlessIntegrations, {
        mocks: createPaymentProviderListLoadingMock(
          GetGocardlessIntegrationsListDocument,
          ProviderTypeEnum.Gocardless,
        ),
      })

      expect(screen.queryByText('Test Connection')).not.toBeInTheDocument()
      expect(container.querySelector('.animate-pulse')).toBeInTheDocument()
    })
  })
})
