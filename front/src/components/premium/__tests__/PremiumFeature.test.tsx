import NiceModal from '@ebay/nice-modal-react'
import { cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactNode } from 'react'

import { PREMIUM_WARNING_DIALOG_NAME } from '~/components/dialogs/const'
import PremiumWarningDialog from '~/components/dialogs/PremiumWarningDialog'
import { render } from '~/test-utils'

import PremiumFeature from '../PremiumFeature'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
    locale: 'en',
  }),
}))

NiceModal.register(PREMIUM_WARNING_DIALOG_NAME, PremiumWarningDialog)

const NiceModalWrapper = ({ children }: { children: ReactNode }) => (
  <NiceModal.Provider>{children}</NiceModal.Provider>
)

const DEFAULT_PROPS = {
  title: 'Test Title',
  description: 'Test Description',
  feature: 'Test Feature',
}

describe('PremiumFeature', () => {
  afterEach(cleanup)

  describe('Basic Rendering', () => {
    it('renders the premium feature container', () => {
      const { container } = render(<PremiumFeature {...DEFAULT_PROPS} />)

      expect(container.firstChild).toBeInTheDocument()
    })

    it('renders the sparkles icon in header', () => {
      const { container } = render(<PremiumFeature {...DEFAULT_PROPS} />)

      // Icon component renders with data-test="sparkles/medium" by default
      const sparklesIcons = container.querySelectorAll('[data-test="sparkles/medium"]')

      expect(sparklesIcons.length).toBeGreaterThanOrEqual(1)
    })

    it('renders a button to upgrade', () => {
      render(<PremiumFeature {...DEFAULT_PROPS} />)

      const button = screen.getByRole('button')

      expect(button).toBeInTheDocument()
    })
  })

  describe('Props Handling', () => {
    it('passes through data-test prop', () => {
      render(<PremiumFeature {...DEFAULT_PROPS} data-test="premium-feature-test-id" />)

      expect(screen.getByTestId('premium-feature-test-id')).toBeInTheDocument()
    })

    it('applies custom className', () => {
      const { container } = render(<PremiumFeature {...DEFAULT_PROPS} className="custom-class" />)

      expect(container.querySelector('.custom-class')).toBeInTheDocument()
    })

    it('renders title in the DOM', () => {
      render(<PremiumFeature {...DEFAULT_PROPS} />)

      expect(screen.getByText(DEFAULT_PROPS.title)).toBeInTheDocument()
    })

    it('renders description in the DOM', () => {
      render(<PremiumFeature {...DEFAULT_PROPS} />)

      expect(screen.getByText(DEFAULT_PROPS.description)).toBeInTheDocument()
    })
  })

  describe('Dialog Interaction', () => {
    it('opens premium warning dialog when button is clicked', async () => {
      const user = userEvent.setup()

      render(
        <NiceModalWrapper>
          <PremiumFeature {...DEFAULT_PROPS} />
        </NiceModalWrapper>,
      )

      const button = screen.getByRole('button')

      await user.click(button)

      await waitFor(() => {
        expect(screen.getByRole('dialog')).toBeInTheDocument()
      })
    })
  })

  describe('Snapshot Tests', () => {
    it('matches snapshot with default props', () => {
      const { container } = render(<PremiumFeature {...DEFAULT_PROPS} />)

      expect(container.firstChild).toMatchSnapshot()
    })

    it('matches snapshot with data-test prop', () => {
      const { container } = render(
        <PremiumFeature {...DEFAULT_PROPS} data-test="premium-feature-test" />,
      )

      expect(container.firstChild).toMatchSnapshot()
    })
  })
})
