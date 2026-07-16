import { screen } from '@testing-library/react'

import { PrivilegeValueTypeEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { EntitlementInfo } from '../EntitlementInfo'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

const entitlement = {
  code: 'seats',
  name: 'Seats',
  privileges: [
    { code: 'max', name: 'Max seats', value: '10', valueType: PrivilegeValueTypeEnum.Integer },
  ],
}

describe('EntitlementInfo', () => {
  it('renders privilege name and value', () => {
    render(<EntitlementInfo entitlement={entitlement} />)
    expect(screen.getByText('Max seats')).toBeInTheDocument()
    expect(screen.getByText('10')).toBeInTheDocument()
  })

  it('renders an empty-state when there are no privileges', () => {
    render(<EntitlementInfo entitlement={{ ...entitlement, privileges: [] }} />)
    expect(screen.getByText('text_1754570508183hxl33n573yk')).toBeInTheDocument()
  })
})
