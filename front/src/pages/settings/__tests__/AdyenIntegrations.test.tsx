import { cleanup, screen, waitFor } from '@testing-library/react'

import { GetAdyenIntegrationsListDocument, ProviderTypeEnum } from '~/generated/graphql'

import {
  createPaymentProviderListLoadingMock,
  createPaymentProviderListMock,
  renderIntegrationPage,
} from './integrationTestHelpers'

import AdyenIntegrations from '../AdyenIntegrations'

jest.mock('~/components/settings/integrations/AddAdyenDialog', () => ({
  AddAdyenDialog: () => null,
}))
jest.mock('~/components/settings/integrations/DeleteAdyenIntegrationDialog', () => ({
  useDeleteAdyenIntegrationDialog: () => ({ openDeleteAdyenIntegrationDialog: () => null }),
}))
jest.mock('~/components/settings/integrations/AddEditDeleteSuccessRedirectUrlDialog', () => ({
  AddEditDeleteSuccessRedirectUrlDialog: () => null,
}))

describe('AdyenIntegrations', () => {
  afterEach(cleanup)

  describe('GIVEN the page is rendered with data', () => {
    it('THEN renders connection items when data is loaded', async () => {
      await renderIntegrationPage(AdyenIntegrations, {
        mocks: createPaymentProviderListMock(
          GetAdyenIntegrationsListDocument,
          ProviderTypeEnum.Adyen,
          'AdyenProvider',
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
      const { container } = await renderIntegrationPage(AdyenIntegrations, {
        mocks: createPaymentProviderListLoadingMock(
          GetAdyenIntegrationsListDocument,
          ProviderTypeEnum.Adyen,
        ),
      })

      expect(screen.queryByText('Test Connection')).not.toBeInTheDocument()
      expect(container.querySelector('.animate-pulse')).toBeInTheDocument()
    })
  })
})
