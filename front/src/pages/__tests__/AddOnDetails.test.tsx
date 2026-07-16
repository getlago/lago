import { render } from '~/test-utils'

import AddOnDetails from '../AddOnDetails'

const mockMainHeaderConfigure = jest.fn()
const mockHasPermissions = jest.fn()
const mockUseGetAddOnForDetailsQuery = jest.fn()

jest.mock('~/components/MainHeader/MainHeader', () => ({
  MainHeader: {
    Configure: (props: Record<string, unknown>) => {
      mockMainHeaderConfigure(props)
      return null
    },
  },
}))

jest.mock('~/components/layouts/DetailsPage', () => ({
  DetailsPage: {
    Container: () => null,
    SectionTitle: () => null,
    InfoGrid: () => null,
    TableDisplay: () => null,
  },
}))

jest.mock('~/components/designSystem/Card', () => ({
  Card: () => null,
}))

jest.mock('~/components/addOns/DeleteAddOnDialog', () => ({
  useDeleteAddOnDialog: () => ({ openDeleteAddOnDialog: jest.fn() }),
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({ hasPermissions: mockHasPermissions }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

jest.mock('~/core/formats/intlFormatNumber', () => ({
  intlFormatNumber: () => '$10.00',
}))

jest.mock('~/core/serializers/serializeAmount', () => ({
  deserializeAmount: () => 10,
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetAddOnForDetailsQuery: (options: Record<string, unknown>) =>
    mockUseGetAddOnForDetailsQuery(options),
}))

interface MainHeaderDropdownAction {
  type: string
  items: { hidden?: boolean; label: string }[]
}

describe('AddOnDetails', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

    useParamsMock.mockReturnValue({ addOnId: 'addon-123' })
    mockUseGetAddOnForDetailsQuery.mockReturnValue({
      data: {
        addOn: {
          id: 'addon-123',
          name: 'Test Add-On',
          amountCents: 1000,
          amountCurrency: 'USD',
          code: 'test-addon',
          taxes: [],
        },
      },
      loading: false,
    })
  })

  describe('GIVEN the component is rendered with data', () => {
    describe('WHEN the add-on is loaded', () => {
      it('THEN should configure MainHeader with breadcrumb', () => {
        mockHasPermissions.mockReturnValue(true)

        render(<AddOnDetails />)

        expect(mockMainHeaderConfigure).toHaveBeenCalledWith(
          expect.objectContaining({
            breadcrumb: expect.arrayContaining([
              expect.objectContaining({
                label: expect.any(String),
                path: expect.any(String),
              }),
            ]),
          }),
        )
      })

      it('THEN should configure MainHeader with entity name and metadata', () => {
        mockHasPermissions.mockReturnValue(true)

        render(<AddOnDetails />)

        expect(mockMainHeaderConfigure).toHaveBeenCalledWith(
          expect.objectContaining({
            entity: expect.objectContaining({
              viewName: 'Test Add-On',
              metadata: expect.any(String),
            }),
          }),
        )
      })

      it('THEN should pass loading false to MainHeader.Configure', () => {
        mockHasPermissions.mockReturnValue(true)

        render(<AddOnDetails />)

        expect(mockMainHeaderConfigure).toHaveBeenCalledWith(
          expect.objectContaining({
            actions: expect.objectContaining({ loading: false }),
          }),
        )
      })
    })

    describe('WHEN add-on is still loading', () => {
      it('THEN should pass loading true to MainHeader.Configure', () => {
        mockUseGetAddOnForDetailsQuery.mockReturnValue({
          data: null,
          loading: true,
        })
        mockHasPermissions.mockReturnValue(true)

        render(<AddOnDetails />)

        expect(mockMainHeaderConfigure).toHaveBeenCalledWith(
          expect.objectContaining({
            actions: expect.objectContaining({ loading: true }),
          }),
        )
      })
    })
  })

  describe('GIVEN user has all permissions', () => {
    describe('WHEN actions are configured', () => {
      it('THEN should include dropdown with edit and delete items', () => {
        mockHasPermissions.mockReturnValue(true)

        render(<AddOnDetails />)

        const actions = mockMainHeaderConfigure.mock.calls[0]?.[0]?.actions
          ?.items as MainHeaderDropdownAction[]

        expect(actions).toHaveLength(1)
        expect(actions[0]?.type).toBe('dropdown')

        const visibleItems = actions[0]?.items.filter((i) => !i.hidden)

        expect(visibleItems).toHaveLength(2)
      })
    })
  })

  describe('GIVEN user has no addonsUpdate permission', () => {
    describe('WHEN actions are configured', () => {
      it('THEN should hide the edit action', () => {
        mockHasPermissions.mockImplementation((perms: string[]) => !perms.includes('addonsUpdate'))

        render(<AddOnDetails />)

        const actions = mockMainHeaderConfigure.mock.calls[0]?.[0]?.actions
          ?.items as MainHeaderDropdownAction[]
        const editItem = actions[0]?.items[0]

        expect(editItem?.hidden).toBe(true)
      })
    })
  })

  describe('GIVEN user has no addonsDelete permission', () => {
    describe('WHEN actions are configured', () => {
      it('THEN should hide the delete action', () => {
        mockHasPermissions.mockImplementation((perms: string[]) => !perms.includes('addonsDelete'))

        render(<AddOnDetails />)

        const actions = mockMainHeaderConfigure.mock.calls[0]?.[0]?.actions
          ?.items as MainHeaderDropdownAction[]
        const deleteItem = actions[0]?.items[1]

        expect(deleteItem?.hidden).toBe(true)
      })
    })
  })
})
