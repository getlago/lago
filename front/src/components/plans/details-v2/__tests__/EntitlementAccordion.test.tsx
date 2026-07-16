import { MockedProvider } from '@apollo/client/testing'
import NiceModal from '@ebay/nice-modal-react'
import { render, screen } from '@testing-library/react'
import { ReactNode } from 'react'

import { FORM_DIALOG_NAME } from '~/components/dialogs/const'
import FormDialog from '~/components/dialogs/FormDialog'
import { PrivilegeValueTypeEnum } from '~/generated/graphql'

import { planDetailsV2Fixture } from './fixtures'

import { EntitlementAccordion } from '../accordions/EntitlementAccordion'

NiceModal.register(FORM_DIALOG_NAME, FormDialog)

// ── Drawer mock ────────────────────────────────────────────────────────────────
const mockOpenDrawer = jest.fn()
const mockCloseDrawer = jest.fn()

jest.mock('~/components/plans/drawers/featureEntitlement/FeatureEntitlementDrawer', () => {
  const { forwardRef, useImperativeHandle } = jest.requireActual('react')

  const FeatureEntitlementDrawer = forwardRef((_props: unknown, ref: unknown) => {
    useImperativeHandle(ref, () => ({ openDrawer: mockOpenDrawer, closeDrawer: mockCloseDrawer }))
    return null
  })

  return { __esModule: true, FeatureEntitlementDrawer }
})

// ── Hook mocks ─────────────────────────────────────────────────────────────────
const mockReset = jest.fn()
const mockSetFieldValue = jest.fn()
const mockSubmit = jest.fn()

jest.mock('~/hooks/plans/useUpdatePlanWithCascade', () => ({
  useUpdatePlanWithCascade: () => ({
    form: {
      reset: mockReset,
      setFieldValue: mockSetFieldValue,
      state: { values: { entitlements: [] } },
    },
    submit: mockSubmit,
  }),
  buildUpdatePlanFormDefaults: () => ({}),
}))

const mockHasPermissions = jest.fn().mockReturnValue(true)

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({ hasPermissions: mockHasPermissions }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

// ── Test wrapper ───────────────────────────────────────────────────────────────
const Wrapper = ({ children }: { children: ReactNode }) => (
  <MockedProvider mocks={[]} addTypename={false}>
    <NiceModal.Provider>{children}</NiceModal.Provider>
  </MockedProvider>
)

// ── Fixtures ───────────────────────────────────────────────────────────────────
const planWithEntitlements = {
  ...planDetailsV2Fixture,
  entitlements: [
    {
      __typename: 'PlanEntitlement' as const,
      code: 'feature_a',
      name: 'Feature A',
      privileges: [
        {
          __typename: 'PlanEntitlementPrivilegeObject' as const,
          code: 'priv_1',
          name: 'Privilege 1',
          value: '100',
          valueType: PrivilegeValueTypeEnum.Integer,
          config: { __typename: 'PrivilegeConfigObject' as const, selectOptions: null },
        },
      ],
    },
    {
      __typename: 'PlanEntitlement' as const,
      code: 'feature_b',
      name: 'Feature B',
      privileges: [],
    },
  ],
}

describe('EntitlementAccordion', () => {
  beforeEach(() => {
    mockOpenDrawer.mockClear()
    mockCloseDrawer.mockClear()
    mockReset.mockClear()
    mockSetFieldValue.mockClear()
    mockSubmit.mockClear()
    mockHasPermissions.mockReset().mockReturnValue(true)
  })

  // ── 1. Renders section anchor and one accordion per entitlement ────────────
  it('renders the section anchor and one accordion per entitlement', () => {
    const { container } = render(<EntitlementAccordion plan={planWithEntitlements} />, {
      wrapper: Wrapper,
    })

    // Section id always present
    expect(container.querySelector('#entitlements')).not.toBeNull()

    // Each entitlement's code appears as a subtitle in the accordion summary
    // (always visible, even when accordion is collapsed)
    expect(screen.getByText('feature_a')).toBeInTheDocument()
    expect(screen.getByText('feature_b')).toBeInTheDocument()

    // Each entitlement's name appears as the accordion title
    expect(screen.getByText('Feature A')).toBeInTheDocument()
    expect(screen.getByText('Feature B')).toBeInTheDocument()
  })

  // ── 2. Add action not rendered when plansCreate permission is missing ───────
  it('does not render the Add action when plansCreate permission is missing', () => {
    // Deny plansCreate but allow everything else
    mockHasPermissions.mockImplementation((perms: string[]) => !perms.includes('plansCreate'))

    render(<EntitlementAccordion plan={planWithEntitlements} />, { wrapper: Wrapper })

    // Add label key must not appear as a button (hidden action is not rendered)
    expect(
      screen.queryByRole('button', { name: 'text_1753864223060devvklm7vk0' }),
    ).not.toBeInTheDocument()
  })

  // ── 3. Edit action hidden when plansUpdate permission is missing ───────────
  it('does not render the Edit action when plansUpdate permission is missing', () => {
    // Deny plansUpdate but allow everything else
    mockHasPermissions.mockImplementation((perms: string[]) => !perms.includes('plansUpdate'))

    render(<EntitlementAccordion plan={planWithEntitlements} />, { wrapper: Wrapper })

    // Edit label key must not appear as a button
    expect(
      screen.queryByRole('button', { name: 'text_63e51ef4985f0ebd75c212fc' }),
    ).not.toBeInTheDocument()
  })
})
