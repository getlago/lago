import { MockedProvider } from '@apollo/client/testing'
import { waitFor } from '@testing-library/react'

import { GetSubscriptionForDetailsV2OverviewDocument } from '~/generated/graphql'
import { render } from '~/test-utils'

import { SubscriptionDetailsV2Overview } from '../SubscriptionDetailsV2Overview'

const capturedInformationProps: Array<Record<string, unknown>> = []
const capturedPaymentProps: Array<Record<string, unknown>> = []
const capturedInvoiceProps: Array<Record<string, unknown>> = []

jest.mock('../SubscriptionInformationSection', () => ({
  __esModule: true,
  SubscriptionInformationSection: (props: Record<string, unknown>) => {
    capturedInformationProps.push(props)

    return null
  },
}))

jest.mock('../SubscriptionPaymentSection', () => ({
  __esModule: true,
  SubscriptionPaymentSection: (props: Record<string, unknown>) => {
    capturedPaymentProps.push(props)

    return null
  },
}))

jest.mock('../SubscriptionInvoiceSection', () => ({
  __esModule: true,
  SubscriptionInvoiceSection: (props: Record<string, unknown>) => {
    capturedInvoiceProps.push(props)

    return null
  },
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

const SUB_ID = 'sub_1'

const queryMock = {
  request: {
    query: GetSubscriptionForDetailsV2OverviewDocument,
    variables: { subscriptionId: SUB_ID },
  },
  result: {
    data: {
      subscription: { id: SUB_ID },
    },
  },
}

describe('SubscriptionDetailsV2Overview', () => {
  beforeEach(() => {
    capturedInformationProps.length = 0
    capturedPaymentProps.length = 0
    capturedInvoiceProps.length = 0
  })

  it('renders the information, payment and invoice sections with the fetched subscription', async () => {
    render(
      <MockedProvider mocks={[queryMock]} addTypename={false}>
        <SubscriptionDetailsV2Overview subscriptionId={SUB_ID} />
      </MockedProvider>,
    )

    await waitFor(() => expect(capturedInformationProps.length).toBeGreaterThan(0))
    await waitFor(() => expect(capturedPaymentProps.length).toBeGreaterThan(0))
    await waitFor(() => expect(capturedInvoiceProps.length).toBeGreaterThan(0))

    expect((capturedInformationProps.at(-1)?.subscription as { id: string }).id).toBe(SUB_ID)
    expect((capturedPaymentProps.at(-1)?.subscription as { id: string }).id).toBe(SUB_ID)
    expect((capturedInvoiceProps.at(-1)?.subscription as { id: string }).id).toBe(SUB_ID)
  })

  it('renders nothing and skips the query when no subscription id is provided', () => {
    render(
      <MockedProvider mocks={[]} addTypename={false}>
        <SubscriptionDetailsV2Overview subscriptionId="" />
      </MockedProvider>,
    )

    expect(capturedInformationProps.length).toBe(0)
  })
})
