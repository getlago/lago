import { cleanup, screen, waitFor } from '@testing-library/react'

import { GetFlutterwaveIntegrationsListDocument, ProviderTypeEnum } from '~/generated/graphql'

import {
  createPaymentProviderListLoadingMock,
  createPaymentProviderListMock,
  renderIntegrationPage,
} from './integrationTestHelpers'

import FlutterwaveIntegrations from '../FlutterwaveIntegrations'

jest.mock('~/components/settings/integrations/AddFlutterwaveDialog', () => ({
  AddFlutterwaveDialog: () => null,
}))
jest.mock('~/components/settings/integrations/DeleteFlutterwaveIntegrationDialog', () => ({
  useDeleteFlutterwaveIntegrationDialog: () => ({
    openDeleteFlutterwaveIntegrationDialog: () => null,
  }),
}))

describe('FlutterwaveIntegrations', () => {
  afterEach(cleanup)

  describe('GIVEN the page is rendered with data', () => {
    it('THEN renders connection items when data is loaded', async () => {
      await renderIntegrationPage(FlutterwaveIntegrations, {
        mocks: createPaymentProviderListMock(
          GetFlutterwaveIntegrationsListDocument,
          ProviderTypeEnum.Flutterwave,
          'FlutterwaveProvider',
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
      const { container } = await renderIntegrationPage(FlutterwaveIntegrations, {
        mocks: createPaymentProviderListLoadingMock(
          GetFlutterwaveIntegrationsListDocument,
          ProviderTypeEnum.Flutterwave,
        ),
      })

      expect(screen.queryByText('Test Connection')).not.toBeInTheDocument()
      expect(container.querySelector('.animate-pulse')).toBeInTheDocument()
    })
  })
})
