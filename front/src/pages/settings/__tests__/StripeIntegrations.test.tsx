import { cleanup, screen, waitFor } from '@testing-library/react'

import { GetStripeIntegrationsListDocument, ProviderTypeEnum } from '~/generated/graphql'

import {
  createPaymentProviderListLoadingMock,
  createPaymentProviderListMock,
  renderIntegrationPage,
} from './integrationTestHelpers'

import StripeIntegrations from '../StripeIntegrations'

jest.mock('~/components/settings/integrations/AddStripeDialog', () => ({
  AddStripeDialog: () => null,
}))
jest.mock('~/components/settings/integrations/DeleteStripeIntegrationDialog', () => ({
  useDeleteStripeIntegrationDialog: () => ({ openDeleteStripeIntegrationDialog: jest.fn() }),
}))
jest.mock('~/components/settings/integrations/AddEditDeleteSuccessRedirectUrlDialog', () => ({
  AddEditDeleteSuccessRedirectUrlDialog: () => null,
}))

describe('StripeIntegrations', () => {
  afterEach(cleanup)

  describe('GIVEN the page is rendered with data', () => {
    it('THEN renders connection items when data is loaded', async () => {
      await renderIntegrationPage(StripeIntegrations, {
        mocks: createPaymentProviderListMock(
          GetStripeIntegrationsListDocument,
          ProviderTypeEnum.Stripe,
          'StripeProvider',
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
      const { container } = await renderIntegrationPage(StripeIntegrations, {
        mocks: createPaymentProviderListLoadingMock(
          GetStripeIntegrationsListDocument,
          ProviderTypeEnum.Stripe,
        ),
      })

      expect(screen.queryByText('Test Connection')).not.toBeInTheDocument()
      expect(container.querySelector('.animate-pulse')).toBeInTheDocument()
    })
  })
})
