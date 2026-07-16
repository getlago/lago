import { renderHook } from '@testing-library/react'

import { CREATE_CUSTOMER_DATA_TEST } from '~/components/customers/utils/dataTestConstants'

import { useCustomersListHeaderActions } from '../useCustomersListHeaderActions'

const mockNavigate = jest.fn()
const mockHasPermissions = jest.fn(() => true)

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useNavigate: () => mockNavigate,
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: mockHasPermissions,
  }),
}))

describe('useCustomersListHeaderActions', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockHasPermissions.mockReturnValue(true)
  })

  describe('GIVEN the user has customersCreate permission', () => {
    describe('WHEN the hook is called', () => {
      it('THEN should return a single create customer action', () => {
        const { result } = renderHook(() => useCustomersListHeaderActions())

        expect(result.current).toHaveLength(1)
        expect(result.current[0]).toMatchObject({
          type: 'action',
          variant: 'primary',
          dataTest: CREATE_CUSTOMER_DATA_TEST,
        })
      })

      it('THEN should navigate to create customer route when action is clicked', () => {
        const { result } = renderHook(() => useCustomersListHeaderActions())

        const action = result.current[0]

        if (action.type === 'action') {
          action.onClick()
        }

        expect(mockNavigate).toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the user does not have customersCreate permission', () => {
    describe('WHEN the hook is called', () => {
      it('THEN should return an empty array', () => {
        mockHasPermissions.mockReturnValue(false)

        const { result } = renderHook(() => useCustomersListHeaderActions())

        expect(result.current).toHaveLength(0)
      })
    })
  })
})
