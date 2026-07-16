import { cleanup, screen, waitFor } from '@testing-library/react'

import { ENTITY_SECTION_VIEW_NAME_TEST_ID } from '~/components/MainHeader/mainHeaderTestIds'

import { renderIntegrationPage } from './integrationTestHelpers'

import SalesforceIntegrationDetails from '../SalesforceIntegrationDetails'

jest.mock('~/components/settings/integrations/AddSalesforceDialog', () => ({
  AddSalesforceDialog: () => null,
}))
jest.mock('~/components/settings/integrations/DeleteSalesforceIntegrationDialog', () => ({
  useDeleteSalesforceIntegrationDialog: () => ({
    openDeleteSalesforceIntegrationDialog: jest.fn(),
  }),
}))

const mockQueryResult = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetSalesforceIntegrationsDetailsQuery: (...args: unknown[]) => mockQueryResult(...args),
}))

describe('SalesforceIntegrationDetails', () => {
  afterEach(cleanup)

  describe('GIVEN the page is rendered with data', () => {
    it('THEN renders integration name in header when loaded', async () => {
      mockQueryResult.mockReturnValue({
        data: {
          integration: {
            __typename: 'SalesforceIntegration',
            id: 'test-id',
            name: 'Test Integration',
            code: 'test-code',
            instanceId: 'sf-instance-123',
          },
          integrations: { __typename: 'IntegrationCollection', collection: [] },
        },
        loading: false,
      })

      await renderIntegrationPage(SalesforceIntegrationDetails, {
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

      const { container } = await renderIntegrationPage(SalesforceIntegrationDetails, {
        useParams: { integrationId: 'test-id' },
      })

      expect(screen.queryByText('Test Integration')).not.toBeInTheDocument()
      expect(container.querySelector('.animate-pulse')).toBeInTheDocument()
    })
  })
})
