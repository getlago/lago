import NiceModal from '@ebay/nice-modal-react'
import { screen } from '@testing-library/react'

import { PREMIUM_WARNING_DIALOG_NAME } from '~/components/dialogs/const'
import PremiumWarningDialog from '~/components/dialogs/PremiumWarningDialog'
import {
  MINIMUM_COMMITMENT_PREMIUM_GATE_TEST_ID,
  MinimumCommitmentPremiumGate,
} from '~/components/plans/MinimumCommitmentPremiumGate'
import { render } from '~/test-utils'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
    locale: 'en',
  }),
}))

NiceModal.register(PREMIUM_WARNING_DIALOG_NAME, PremiumWarningDialog)

describe('MinimumCommitmentPremiumGate', () => {
  it('renders PremiumFeature with minimum-commitment title + description', () => {
    render(<MinimumCommitmentPremiumGate />)

    const gate = screen.getByTestId(MINIMUM_COMMITMENT_PREMIUM_GATE_TEST_ID)

    expect(gate).toBeInTheDocument()
    expect(gate).toHaveTextContent('text_17700400130439xuo82ha60n')
    expect(gate).toHaveTextContent('text_1770040013043awgs0eemonf')
  })
})
