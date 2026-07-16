import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { PrivilegeValueTypeEnum } from '~/generated/graphql'
import { render } from '~/test-utils'
import { createMockPlanForm } from '~/test-utils/createMockPlanForm'

import {
  ADD_FEATURE_ENTITLEMENT_TEST_ID,
  FEATURE_ENTITLEMENT_SELECTOR_TEST_ID,
  FeatureEntitlementSection,
} from '../FeatureEntitlementSection'
import { LocalEntitlementInput, PlanFormInput } from '../types'

// --- Mocks ---

const mockOpenDrawer = jest.fn()
const mockCloseDrawer = jest.fn()

jest.mock('~/components/plans/drawers/featureEntitlement/FeatureEntitlementDrawer', () => {
  const React = jest.requireActual('react')

  const MockedDrawer = React.forwardRef((_props: unknown, ref: unknown) => {
    React.useImperativeHandle(ref, () => ({
      openDrawer: mockOpenDrawer,
      closeDrawer: mockCloseDrawer,
    }))

    return React.createElement('div', { 'data-test': 'feature-entitlement-drawer-mock' })
  })

  MockedDrawer.displayName = 'FeatureEntitlementDrawer'

  return {
    FeatureEntitlementDrawer: MockedDrawer,
    FeatureEntitlementDrawerRef: {},
  }
})

// --- Helpers ---

const createForm = (overrides: Partial<PlanFormInput> = {}) => createMockPlanForm(overrides)

const createEntitlement = (
  overrides: Partial<LocalEntitlementInput> = {},
): LocalEntitlementInput => ({
  featureId: 'feature-1',
  featureName: 'Feature One',
  featureCode: 'feature_one',
  privileges: [],
  ...overrides,
})

const defaultProps = {
  form: createForm(),
}

describe('FeatureEntitlementSection', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN no entitlements exist', () => {
    describe('WHEN the component is rendered', () => {
      it('THEN should render the add button', () => {
        render(<FeatureEntitlementSection {...defaultProps} />)

        expect(screen.getByTestId(ADD_FEATURE_ENTITLEMENT_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render the FeatureEntitlementDrawer', () => {
        render(<FeatureEntitlementSection {...defaultProps} />)

        expect(screen.getByTestId('feature-entitlement-drawer-mock')).toBeInTheDocument()
      })

      it('THEN should not render any selectors', () => {
        render(<FeatureEntitlementSection {...defaultProps} />)

        expect(screen.queryByTestId(FEATURE_ENTITLEMENT_SELECTOR_TEST_ID)).not.toBeInTheDocument()
      })
    })

    describe('WHEN the add button is clicked', () => {
      it('THEN should open the drawer with no values', async () => {
        const user = userEvent.setup()

        render(<FeatureEntitlementSection {...defaultProps} />)

        await user.click(screen.getByTestId(ADD_FEATURE_ENTITLEMENT_TEST_ID))

        expect(mockOpenDrawer).toHaveBeenCalledWith()
      })
    })
  })

  describe('GIVEN entitlements exist', () => {
    const entitlements: LocalEntitlementInput[] = [
      createEntitlement(),
      createEntitlement({
        featureId: 'feature-2',
        featureName: 'Feature Two',
        featureCode: 'feature_two',
        privileges: [
          {
            privilegeCode: 'priv_1',
            privilegeName: 'Privilege One',
            value: 'true',
            valueType: PrivilegeValueTypeEnum.Boolean,
          },
        ],
      }),
    ]
    const formWithEntitlements = createForm({ entitlements })

    describe('WHEN the component is rendered', () => {
      it('THEN should render a selector for each entitlement', () => {
        render(<FeatureEntitlementSection {...defaultProps} form={formWithEntitlements} />)

        const selectors = screen.getAllByTestId(FEATURE_ENTITLEMENT_SELECTOR_TEST_ID)

        expect(selectors).toHaveLength(2)
      })

      it('THEN should still render the add button', () => {
        render(<FeatureEntitlementSection {...defaultProps} form={formWithEntitlements} />)

        expect(screen.getByTestId(ADD_FEATURE_ENTITLEMENT_TEST_ID)).toBeInTheDocument()
      })
    })

    describe('WHEN a selector is clicked', () => {
      it('THEN should open the drawer with the entitlement values', async () => {
        const user = userEvent.setup()

        render(<FeatureEntitlementSection {...defaultProps} form={formWithEntitlements} />)

        const selectors = screen.getAllByTestId(FEATURE_ENTITLEMENT_SELECTOR_TEST_ID)

        await user.click(selectors[1])

        expect(mockOpenDrawer).toHaveBeenCalledWith({
          featureId: 'feature-2',
          featureName: 'Feature Two',
          featureCode: 'feature_two',
          privileges: [
            {
              privilegeCode: 'priv_1',
              privilegeName: 'Privilege One',
              value: 'true',
              valueType: PrivilegeValueTypeEnum.Boolean,
            },
          ],
        })
      })
    })

    describe('WHEN an entitlement has no featureName', () => {
      it('THEN should display the featureCode as the selector title', () => {
        const entitlementsNoName: LocalEntitlementInput[] = [
          createEntitlement({ featureName: '', featureCode: 'my_code' }),
        ]

        render(
          <FeatureEntitlementSection
            {...defaultProps}
            form={createForm({ entitlements: entitlementsNoName })}
          />,
        )

        const selector = screen.getByTestId(FEATURE_ENTITLEMENT_SELECTOR_TEST_ID)

        expect(selector).toHaveTextContent('my_code')
      })
    })

    describe('WHEN an entitlement has no featureId', () => {
      it('THEN should pass empty string as featureId to the drawer', async () => {
        const user = userEvent.setup()
        const entitlementsNoId: LocalEntitlementInput[] = [
          createEntitlement({ featureId: undefined }),
        ]

        render(
          <FeatureEntitlementSection
            {...defaultProps}
            form={createForm({ entitlements: entitlementsNoId })}
          />,
        )

        await user.click(screen.getByTestId(FEATURE_ENTITLEMENT_SELECTOR_TEST_ID))

        expect(mockOpenDrawer).toHaveBeenCalledWith(expect.objectContaining({ featureId: '' }))
      })
    })

    describe('WHEN an entitlement has no privileges', () => {
      it('THEN should pass empty array as privileges to the drawer', async () => {
        const user = userEvent.setup()
        const entitlementsNoPriv: LocalEntitlementInput[] = [
          createEntitlement({
            privileges: undefined as unknown as LocalEntitlementInput['privileges'],
          }),
        ]

        render(
          <FeatureEntitlementSection
            {...defaultProps}
            form={createForm({ entitlements: entitlementsNoPriv })}
          />,
        )

        await user.click(screen.getByTestId(FEATURE_ENTITLEMENT_SELECTOR_TEST_ID))

        expect(mockOpenDrawer).toHaveBeenCalledWith(expect.objectContaining({ privileges: [] }))
      })
    })
  })
})
