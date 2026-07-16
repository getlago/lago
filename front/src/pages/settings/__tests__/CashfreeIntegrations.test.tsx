import { cleanup, screen, waitFor } from '@testing-library/react'

import { GetCashfreeIntegrationsListDocument, ProviderTypeEnum } from '~/generated/graphql'

import {
  createPaymentProviderListLoadingMock,
  createPaymentProviderListMock,
  renderIntegrationPage,
} from './integrationTestHelpers'

import CashfreeIntegrations from '../CashfreeIntegrations'

jest.mock('~/components/settings/integrations/AddCashfreeDialog', () => ({
  AddCashfreeDialog: () => null,
}))
jest.mock('~/components/settings/integrations/DeleteCashfreeIntegrationDialog', () => ({
  useDeleteCashfreeIntegrationDialog: () => ({
    openDeleteCashfreeIntegrationDialog: jest.fn(),
  }),
}))
jest.mock('~/components/settings/integrations/AddEditDeleteSuccessRedirectUrlDialog', () => ({
  AddEditDeleteSuccessRedirectUrlDialog: () => null,
}))

describe('CashfreeIntegrations', () => {
  afterEach(cleanup)

  describe('GIVEN the page is rendered with data', () => {
    it('THEN renders connection items when data is loaded', async () => {
      await renderIntegrationPage(CashfreeIntegrations, {
        mocks: createPaymentProviderListMock(
          GetCashfreeIntegrationsListDocument,
          ProviderTypeEnum.Cashfree,
          'CashfreeProvider',
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
      const { container } = await renderIntegrationPage(CashfreeIntegrations, {
        mocks: createPaymentProviderListLoadingMock(
          GetCashfreeIntegrationsListDocument,
          ProviderTypeEnum.Cashfree,
        ),
      })

      expect(screen.queryByText('Test Connection')).not.toBeInTheDocument()
      expect(container.querySelector('.animate-pulse')).toBeInTheDocument()
    })
  })
})
