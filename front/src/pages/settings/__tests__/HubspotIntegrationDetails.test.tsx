import { cleanup, screen, waitFor } from '@testing-library/react'

import { ENTITY_SECTION_VIEW_NAME_TEST_ID } from '~/components/MainHeader/mainHeaderTestIds'

import { renderIntegrationPage } from './integrationTestHelpers'

import HubspotIntegrationDetails from '../HubspotIntegrationDetails'

jest.mock('~/components/settings/integrations/AddHubspotDialog', () => ({
  AddHubspotDialog: () => null,
}))
jest.mock('~/components/settings/integrations/DeleteHubspotIntegrationDialog', () => ({
  useDeleteHubspotIntegrationDialog: () => ({
    openDeleteHubspotIntegrationDialog: jest.fn(),
  }),
}))

const mockQueryResult = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetHubspotIntegrationsDetailsQuery: (...args: unknown[]) => mockQueryResult(...args),
}))

describe('HubspotIntegrationDetails', () => {
  afterEach(cleanup)

  describe('GIVEN the page is rendered with data', () => {
    it('THEN renders integration name in header when loaded', async () => {
      mockQueryResult.mockReturnValue({
        data: {
          integration: {
            __typename: 'HubspotIntegration',
            id: 'test-id',
            name: 'Test Integration',
            code: 'test-code',
            defaultTargetedObject: 'Companies',
            syncInvoices: true,
            syncSubscriptions: false,
          },
          integrations: { __typename: 'IntegrationCollection', collection: [] },
        },
        loading: false,
      })

      await renderIntegrationPage(HubspotIntegrationDetails, {
        useParams: { integrationId: 'test-id' },
      })

      await waitFor(() => {
        const viewName = screen.getAllByTestId(ENTITY_SECTION_VIEW_NAME_TEST_ID)

        expect(viewName[0]).toHaveTextContent('Test Integration')
      })
    })
  })

  describe('GIVEN the page is loading', () => {
    it('THEN renders loading state', async () => {
      mockQueryResult.mockReturnValue({ data: undefined, loading: true })

      const { container } = await renderIntegrationPage(HubspotIntegrationDetails, {
        useParams: { integrationId: 'test-id' },
      })

      expect(screen.queryByText('Test Integration')).not.toBeInTheDocument()
      expect(container.querySelector('.animate-pulse')).toBeInTheDocument()
    })
  })
})
