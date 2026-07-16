import { fireEvent, screen } from '@testing-library/react'

import { render } from '~/test-utils'

import MonthSelectorDropdown, {
  AnalyticsPeriodScopeEnum,
  MONTH_SELECTOR_COMBO_BOX,
} from '../MonthSelectorDropdown'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const mockIsPremium = jest.fn<boolean, []>()

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({
    isPremium: mockIsPremium(),
  }),
}))

const mockOpenPremiumWarningDialog = jest.fn()

jest.mock('~/components/dialogs/PremiumWarningDialog', () => ({
  usePremiumWarningDialog: () => ({
    open: mockOpenPremiumWarningDialog,
  }),
}))

describe('MonthSelectorDropdown', () => {
  const defaultProps = {
    periodScope: AnalyticsPeriodScopeEnum.Year,
    setPeriodScope: jest.fn(),
  }

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN a non-premium user', () => {
    beforeEach(() => {
      mockIsPremium.mockReturnValue(false)
    })

    describe('WHEN the component renders', () => {
      it('THEN should render a locked picker box', () => {
        render(<MonthSelectorDropdown {...defaultProps} />)

        const lockedInput = screen.getByTestId('locked-picker-box') as HTMLInputElement

        expect(lockedInput).toBeInTheDocument()
        expect(lockedInput.readOnly).toBe(true)
      })

      it('THEN should not render the combo box', () => {
        render(<MonthSelectorDropdown {...defaultProps} />)

        expect(screen.queryByTestId(MONTH_SELECTOR_COMBO_BOX)).not.toBeInTheDocument()
      })
    })

    describe('WHEN the locked picker is clicked', () => {
      it('THEN should open the premium warning dialog', () => {
        render(<MonthSelectorDropdown {...defaultProps} />)

        const lockedInput = screen.getByTestId('locked-picker-box')

        fireEvent.click(lockedInput)

        expect(mockOpenPremiumWarningDialog).toHaveBeenCalledTimes(1)
      })
    })
  })

  describe('GIVEN a premium user', () => {
    beforeEach(() => {
      mockIsPremium.mockReturnValue(true)
    })

    describe('WHEN the component renders', () => {
      it('THEN should render the combo box', () => {
        render(<MonthSelectorDropdown {...defaultProps} />)

        expect(screen.getByTestId(MONTH_SELECTOR_COMBO_BOX)).toBeInTheDocument()
      })

      it('THEN should not render a locked picker box', () => {
        render(<MonthSelectorDropdown {...defaultProps} />)

        expect(screen.queryByTestId('locked-picker-box')).not.toBeInTheDocument()
      })
    })
  })
})
