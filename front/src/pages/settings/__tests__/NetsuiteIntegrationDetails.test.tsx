import { cleanup, screen, waitFor } from '@testing-library/react'

import { ENTITY_SECTION_VIEW_NAME_TEST_ID } from '~/components/MainHeader/mainHeaderTestIds'

import { renderIntegrationPage } from './integrationTestHelpers'

import NetsuiteIntegrationDetails from '../NetsuiteIntegrationDetails'

jest.mock('~/components/settings/integrations/AddNetsuiteDialog', () => ({
  AddNetsuiteDialog: () => null,
}))
jest.mock('~/components/settings/integrations/DeleteNetsuiteIntegrationDialog', () => ({
  useDeleteNetsuiteIntegrationDialog: () => ({ openDeleteNetsuiteIntegrationDialog: jest.fn() }),
}))
jest.mock('~/components/settings/integrations/AddEditDeleteSuccessRedirectUrlDialog', () => ({
  AddEditDeleteSuccessRedirectUrlDialog: () => null,
}))
jest.mock('~/components/settings/integrations/NetsuiteIntegrationSettings', () => ({
  __esModule: true,
  default: () => null,
}))
jest.mock('~/components/settings/integrations/NetsuiteIntegrationItemsList', () => ({
  __esModule: true,
  default: () => null,
}))
jest.mock('~/pages/settings/integrations/NetsuiteAdditionalMappings', () => ({
  NetsuiteAdditionalMappings: () => null,
}))

const mockQueryResult = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetNetsuiteIntegrationsDetailsQuery: (...args: unknown[]) => mockQueryResult(...args),
}))

describe('NetsuiteIntegrationDetails', () => {
  afterEach(cleanup)

  describe('GIVEN the page is rendered with data', () => {
    it('THEN renders integration name in header when loaded', async () => {
      mockQueryResult.mockReturnValue({
        data: {
          integration: {
            __typename: 'NetsuiteIntegration',
            id: 'test-id',
            name: 'Test Integration',
          },
          integrations: { __typename: 'IntegrationCollection', collection: [] },
        },
        loading: false,
      })

      await renderIntegrationPage(NetsuiteIntegrationDetails, {
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

      const { container } = await renderIntegrationPage(NetsuiteIntegrationDetails, {
        useParams: { integrationId: 'test-id' },
      })

      expect(screen.queryByText('Test Integration')).not.toBeInTheDocument()
      expect(container.querySelector('.animate-pulse')).toBeInTheDocument()
    })
  })
})
