import NiceModal from '@ebay/nice-modal-react'
import { screen } from '@testing-library/react'

import { PREMIUM_WARNING_DIALOG_NAME } from '~/components/dialogs/const'
import PremiumWarningDialog from '~/components/dialogs/PremiumWarningDialog'
import {
  PROGRESSIVE_BILLING_PREMIUM_GATE_TEST_ID,
  ProgressiveBillingPremiumGate,
} from '~/components/plans/ProgressiveBillingPremiumGate'
import { render } from '~/test-utils'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
    locale: 'en',
  }),
}))

NiceModal.register(PREMIUM_WARNING_DIALOG_NAME, PremiumWarningDialog)

describe('ProgressiveBillingPremiumGate', () => {
  it('renders PremiumFeature with progressive-billing title + description', () => {
    render(<ProgressiveBillingPremiumGate />)

    const gate = screen.getByTestId(PROGRESSIVE_BILLING_PREMIUM_GATE_TEST_ID)

    expect(gate).toBeInTheDocument()
    expect(gate).toHaveTextContent('text_1724345142892pcnx5m2k3r2')
    expect(gate).toHaveTextContent('text_1724345142892ljzi79afhmc')
  })
})
