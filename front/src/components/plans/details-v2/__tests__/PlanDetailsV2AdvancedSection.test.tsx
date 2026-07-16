import { render } from '@testing-library/react'

import { planDetailsV2Fixture } from './fixtures'

import { PlanDetailsV2AdvancedSection } from '../PlanDetailsV2AdvancedSection'
import { PlanDetailsV2SectionId } from '../sidebarSections'

const mockMinimumCommitmentAccordion = jest.fn()
const mockProgressiveBillingAccordion = jest.fn()
const mockEntitlementAccordion = jest.fn()

jest.mock('../accordions/MinimumCommitmentAccordion', () => ({
  __esModule: true,
  MinimumCommitmentAccordion: (props: unknown) => {
    mockMinimumCommitmentAccordion(props)
    return null
  },
}))

jest.mock('../accordions/ProgressiveBillingAccordion', () => ({
  __esModule: true,
  ProgressiveBillingAccordion: (props: unknown) => {
    mockProgressiveBillingAccordion(props)
    return null
  },
}))

jest.mock('../accordions/EntitlementAccordion', () => ({
  __esModule: true,
  EntitlementAccordion: (props: unknown) => {
    mockEntitlementAccordion(props)
    return null
  },
}))

describe('PlanDetailsV2AdvancedSection', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the section is rendered for a plan details view', () => {
    describe('WHEN isInSubscriptionForm is false (default)', () => {
      it('THEN should render the section anchor with the advanced-settings id', () => {
        const { container } = render(<PlanDetailsV2AdvancedSection plan={planDetailsV2Fixture} />)

        expect(
          container.querySelector(`#${PlanDetailsV2SectionId.AdvancedSettings}`),
        ).toBeInTheDocument()
      })

      it.each([
        ['minimum commitment', () => mockMinimumCommitmentAccordion],
        ['progressive billing', () => mockProgressiveBillingAccordion],
        ['entitlements', () => mockEntitlementAccordion],
      ])('THEN should render the %s accordion', (_, getMock) => {
        render(<PlanDetailsV2AdvancedSection plan={planDetailsV2Fixture} />)

        expect(getMock()).toHaveBeenCalledTimes(1)
      })

      it.each([
        ['minimum commitment', () => mockMinimumCommitmentAccordion],
        ['progressive billing', () => mockProgressiveBillingAccordion],
        ['entitlements', () => mockEntitlementAccordion],
      ])(
        'THEN should forward plan + isInSubscriptionForm=false to the %s accordion',
        (_, getMock) => {
          render(<PlanDetailsV2AdvancedSection plan={planDetailsV2Fixture} />)

          expect(getMock()).toHaveBeenCalledWith(
            expect.objectContaining({
              plan: planDetailsV2Fixture,
              isInSubscriptionForm: false,
            }),
          )
        },
      )
    })

    describe('WHEN isInSubscriptionForm is true', () => {
      it('THEN should still render the minimum commitment accordion', () => {
        render(
          <PlanDetailsV2AdvancedSection plan={planDetailsV2Fixture} isInSubscriptionForm={true} />,
        )

        expect(mockMinimumCommitmentAccordion).toHaveBeenCalledTimes(1)
        expect(mockMinimumCommitmentAccordion).toHaveBeenCalledWith(
          expect.objectContaining({ isInSubscriptionForm: true }),
        )
      })

      it.each([
        ['progressive billing', () => mockProgressiveBillingAccordion],
        ['entitlements', () => mockEntitlementAccordion],
      ])('THEN should NOT render the %s accordion', (_, getMock) => {
        render(
          <PlanDetailsV2AdvancedSection plan={planDetailsV2Fixture} isInSubscriptionForm={true} />,
        )

        expect(getMock()).not.toHaveBeenCalled()
      })
    })
  })
})
