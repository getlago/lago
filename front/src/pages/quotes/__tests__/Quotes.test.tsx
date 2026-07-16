import { screen } from '@testing-library/react'

import { MainHeaderConfig } from '~/components/MainHeader/types'
import { render } from '~/test-utils'

import Quotes, { CREATE_QUOTE_BUTTON_TEST_ID } from '../Quotes'

let capturedConfig: MainHeaderConfig | null = null

jest.mock('~/components/MainHeader/MainHeader', () => ({
  MainHeader: Object.assign(() => null, {
    Configure: (props: MainHeaderConfig) => {
      capturedConfig = props
      return null
    },
  }),
}))

jest.mock('~/components/MainHeader/useMainHeaderTabContent', () => ({
  useMainHeaderTabContent: () => <div data-test="active-tab-content-mock">Tab Content</div>,
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const mockNavigate = jest.fn()
const mockUseParams = jest.fn()

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useNavigate: () => mockNavigate,
  useLocation: () => ({ pathname: '/quotes/quotes' }),
  useParams: () => mockUseParams(),
}))

const mockHasPermissions = jest.fn()

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({ hasPermissions: mockHasPermissions }),
}))

const mockIsPremium = jest.fn()

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({ isPremium: mockIsPremium() }),
}))

describe('Quotes', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    capturedConfig = null
    mockIsPremium.mockReturnValue(true)
    mockUseParams.mockReturnValue({})
  })

  describe('GIVEN the page is rendered', () => {
    describe('WHEN in default state', () => {
      it('THEN should configure MainHeader with entity viewName', () => {
        mockHasPermissions.mockReturnValue(true)

        render(<Quotes />)

        expect(capturedConfig?.entity?.viewName).toEqual(expect.any(String))
      })

      it('THEN should configure MainHeader with three tabs', () => {
        mockHasPermissions.mockReturnValue(true)

        render(<Quotes />)

        expect(capturedConfig?.tabs).toHaveLength(3)
      })

      it('THEN should have a Quotes tab as the first tab', () => {
        mockHasPermissions.mockReturnValue(true)

        render(<Quotes />)

        expect(capturedConfig?.tabs?.[0].title).toEqual(expect.any(String))
        expect(capturedConfig?.tabs?.[0].link).toBe('/quotes/quotes')
      })

      it('THEN should have an Order forms tab as the second tab', () => {
        mockHasPermissions.mockReturnValue(true)

        render(<Quotes />)

        expect(capturedConfig?.tabs?.[1].title).toEqual(expect.any(String))
        expect(capturedConfig?.tabs?.[1].link).toBe('/quotes/order-forms')
      })

      it('THEN should have an Orders tab as the third tab', () => {
        mockHasPermissions.mockReturnValue(true)

        render(<Quotes />)

        expect(capturedConfig?.tabs?.[2].title).toEqual(expect.any(String))
        expect(capturedConfig?.tabs?.[2].link).toBe('/quotes/orders')
      })

      it('THEN should hide the Order forms tab without the orderFormsView permission', () => {
        mockHasPermissions.mockReturnValue(false)

        render(<Quotes />)

        expect(capturedConfig?.tabs).toHaveLength(2)
        expect(capturedConfig?.tabs?.some((tab) => tab.link?.endsWith('/order-forms'))).toBe(false)
      })

      it('THEN should render the active tab content', () => {
        mockHasPermissions.mockReturnValue(true)

        render(<Quotes />)

        expect(screen.getByTestId('active-tab-content-mock')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the user has quotesCreate permission', () => {
    describe('WHEN the page renders', () => {
      it('THEN should configure MainHeader with a visible create action', () => {
        mockHasPermissions.mockImplementation((perms: string[]) => perms.includes('quotesCreate'))

        render(<Quotes />)

        expect(capturedConfig?.actions).toEqual(
          expect.objectContaining({
            items: expect.arrayContaining([
              expect.objectContaining({
                type: 'action',
                dataTest: CREATE_QUOTE_BUTTON_TEST_ID,
                hidden: false,
              }),
            ]),
          }),
        )
      })
    })
  })

  describe('GIVEN the user does not have quotesCreate permission', () => {
    describe('WHEN the page renders', () => {
      it('THEN should configure MainHeader with a hidden create action', () => {
        mockHasPermissions.mockReturnValue(false)

        render(<Quotes />)

        expect(capturedConfig?.actions).toEqual(
          expect.objectContaining({
            items: expect.arrayContaining([
              expect.objectContaining({
                type: 'action',
                dataTest: CREATE_QUOTE_BUTTON_TEST_ID,
                hidden: true,
              }),
            ]),
          }),
        )
      })
    })
  })

  describe('GIVEN the user is not premium', () => {
    beforeEach(() => {
      mockIsPremium.mockReturnValue(false)
      mockHasPermissions.mockReturnValue(true)
    })

    describe('WHEN the page renders', () => {
      it('THEN should configure MainHeader without tabs', () => {
        render(<Quotes />)

        expect(capturedConfig?.tabs).toBeUndefined()
      })

      it('THEN should configure MainHeader without actions', () => {
        render(<Quotes />)

        expect(capturedConfig?.actions).toBeUndefined()
      })

      it('THEN should not render the active tab content', () => {
        render(<Quotes />)

        expect(screen.queryByTestId('active-tab-content-mock')).not.toBeInTheDocument()
      })

      it('THEN should render the premium feature paywall', () => {
        render(<Quotes />)

        expect(screen.getByTestId('quotes-premium-feature')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the user is on the Quotes tab', () => {
    beforeEach(() => {
      mockHasPermissions.mockReturnValue(true)
      mockUseParams.mockReturnValue({ tab: 'quotes' })
    })

    describe('WHEN the page renders', () => {
      it('THEN should configure MainHeader with the quotes snapshotKey', () => {
        render(<Quotes />)

        expect(capturedConfig?.snapshotKey).toBe('quotes')
      })

      it('THEN should configure MainHeader with a filters section', () => {
        render(<Quotes />)

        expect(capturedConfig?.filtersSection).toBeDefined()
      })
    })
  })

  describe('GIVEN the user is on the Order Forms tab', () => {
    beforeEach(() => {
      mockHasPermissions.mockReturnValue(true)
      mockUseParams.mockReturnValue({ tab: 'order-forms' })
    })

    describe('WHEN the page renders', () => {
      it('THEN should configure MainHeader with the order-forms snapshotKey', () => {
        render(<Quotes />)

        expect(capturedConfig?.snapshotKey).toBe('order-forms')
      })

      it('THEN should configure MainHeader with a filters section', () => {
        render(<Quotes />)

        expect(capturedConfig?.filtersSection).toBeDefined()
      })
    })
  })

  describe('GIVEN the user is on the Orders tab', () => {
    beforeEach(() => {
      mockHasPermissions.mockReturnValue(true)
      mockUseParams.mockReturnValue({ tab: 'orders' })
    })

    describe('WHEN the page renders', () => {
      it('THEN should configure MainHeader with the orders snapshotKey', () => {
        render(<Quotes />)

        expect(capturedConfig?.snapshotKey).toBe('orders')
      })

      it('THEN should configure MainHeader with a filters section', () => {
        render(<Quotes />)

        expect(capturedConfig?.filtersSection).toBeDefined()
      })
    })
  })
})
