import { screen } from '@testing-library/react'

import type { VirtualFilterListProps } from '~/components/designSystem/VirtualList/VirtualFilterList'
import {
  ChargeModelEnum,
  CurrencyEnum,
  PlanInterval,
  RegroupPaidFeesEnum,
} from '~/generated/graphql'
import { render } from '~/test-utils'

import { UsageChargeInfo, UsageChargeInfoCharge } from '../UsageChargeInfo'

// Stays in lockstep with the real component: if renderItem's signature changes,
// this breaks at compile time instead of silently drifting.
type CapturedVirtualListProps = Pick<VirtualFilterListProps<unknown>, 'items' | 'renderItem'>

const capturedVirtualList: { props?: CapturedVirtualListProps } = {}

jest.mock('~/components/designSystem/VirtualList/VirtualFilterList', () => ({
  VIRTUALIZATION_THRESHOLD: 50,
  // Delegate to renderItem so existing content assertions still see real
  // output, while capturing props for the drift assertion below.
  VirtualFilterList: (props: CapturedVirtualListProps) => (
    <>
      {props.items.map((item, index) => {
        capturedVirtualList.props = props

        return <div key={index}>{props.renderItem(item, index)}</div>
      })}
    </>
  ),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (k: string) => k }),
}))

const buildCharge = (overrides: Partial<UsageChargeInfoCharge> = {}): UsageChargeInfoCharge => ({
  __typename: 'Charge',
  id: 'charge_1',
  chargeModel: ChargeModelEnum.Standard,
  invoiceDisplayName: null,
  invoiceable: true,
  payInAdvance: false,
  prorated: false,
  minAmountCents: '0',
  regroupPaidFees: null,
  properties: { amount: '10', graduatedRanges: null, volumeRanges: null } as never,
  filters: [],
  appliedPricingUnit: null,
  taxes: [],
  billableMetric: {
    __typename: 'BillableMetric',
    id: 'bm_1',
    name: 'API calls',
    code: 'api_calls',
    recurring: false,
    filters: [],
  } as never,
  ...overrides,
})

describe('UsageChargeInfo', () => {
  it('renders standard charge amount via PlanDetailsChargeWrapperSwitch', () => {
    render(
      <UsageChargeInfo
        charge={buildCharge()}
        currency={CurrencyEnum.Usd}
        planInterval={PlanInterval.Monthly}
        planTaxes={[]}
      />,
    )
    expect(screen.getByText('text_65201b8216455901fe273dd5')).toBeInTheDocument()
  })

  it('renders presentation group keys from charge properties', () => {
    render(
      <UsageChargeInfo
        charge={buildCharge({
          properties: {
            __typename: 'Properties',
            amount: '10',
            pricingGroupKeys: ['region'],
            presentationGroupKeys: [
              {
                __typename: 'PresentationGroupKey',
                value: 'account_manager',
                options: {
                  __typename: 'PresentationGroupKeyOptions',
                  displayInInvoice: true,
                },
              },
              {
                __typename: 'PresentationGroupKey',
                value: 'product_area',
                options: {
                  __typename: 'PresentationGroupKeyOptions',
                  displayInInvoice: false,
                },
              },
            ],
          } as never,
        })}
        currency={CurrencyEnum.Usd}
        planInterval={PlanInterval.Monthly}
        planTaxes={[]}
      />,
    )

    expect(screen.getByText('text_65ba6d45e780c1ff8acb20ce')).toBeInTheDocument()
    expect(screen.getByText('region')).toBeInTheDocument()
    expect(screen.getByText('text_17774502138912d3etwcacpe')).toBeInTheDocument()
    expect(screen.getByText('text_1777456950225zgyccgcm3x4')).toBeInTheDocument()
    expect(screen.getByText('account_manager')).toBeInTheDocument()
    expect(screen.getByText('text_1777456950225qhho55pdxm8')).toBeInTheDocument()
    expect(screen.getByText('product_area')).toBeInTheDocument()
  })

  it('does not render a filter sub-accordion when charge has no filters', () => {
    render(
      <UsageChargeInfo
        charge={buildCharge({ filters: [] })}
        currency={CurrencyEnum.Usd}
        planInterval={PlanInterval.Monthly}
        planTaxes={[]}
      />,
    )
    expect(screen.queryByText('text_64e620bca31226337ffc62ad')).not.toBeInTheDocument()
  })

  it('renders the filter sub-accordion when charge has filters', () => {
    const charge = buildCharge({
      filters: [
        {
          __typename: 'ChargeFilter',
          id: 'flt_1',
          invoiceDisplayName: 'Region: EU',
          values: ['{"region":"eu"}'] as never,
          properties: { amount: '15', graduatedRanges: null, volumeRanges: null } as never,
        } as never,
      ],
    })

    render(
      <UsageChargeInfo
        charge={charge}
        currency={CurrencyEnum.Usd}
        planInterval={PlanInterval.Monthly}
        planTaxes={[]}
      />,
    )
    expect(screen.getByText('Region: EU')).toBeInTheDocument()
  })

  it('renders presentation group keys above price accordions when charge has filters', () => {
    const charge = buildCharge({
      properties: {
        __typename: 'Properties',
        amount: '10',
        presentationGroupKeys: [
          {
            __typename: 'PresentationGroupKey',
            value: 'account_manager',
            options: {
              __typename: 'PresentationGroupKeyOptions',
              displayInInvoice: true,
            },
          },
        ],
      } as never,
      billableMetric: {
        __typename: 'BillableMetric',
        id: 'bm_with_filters',
        name: 'API calls',
        code: 'api_calls',
        recurring: false,
        filters: [{ id: 'region', key: 'region', values: ['eu'] }],
      } as never,
    })

    render(
      <UsageChargeInfo
        charge={charge}
        currency={CurrencyEnum.Usd}
        planInterval={PlanInterval.Monthly}
        planTaxes={[]}
      />,
    )

    expect(screen.getByText('text_17774502138912d3etwcacpe')).toBeInTheDocument()
    expect(screen.getByText('account_manager')).toBeInTheDocument()
    expect(screen.getByText('text_64e620bca31226337ffc62ad')).toBeInTheDocument()
  })

  it('renders "Pay later" when payInAdvance is false', () => {
    render(
      <UsageChargeInfo
        charge={buildCharge({ payInAdvance: false })}
        currency={CurrencyEnum.Usd}
        planInterval={PlanInterval.Monthly}
        planTaxes={[]}
      />,
    )
    expect(screen.getByText('text_646e2d0cc536351b62ba6f8c')).toBeInTheDocument()
  })

  it('falls back to invoiced strategy when payInAdvance + invoiceable', () => {
    render(
      <UsageChargeInfo
        charge={buildCharge({ payInAdvance: true, invoiceable: true })}
        currency={CurrencyEnum.Usd}
        planInterval={PlanInterval.Monthly}
        planTaxes={[]}
      />,
    )
    expect(screen.getByText('text_66968fba80f8f89a8aefdebf')).toBeInTheDocument()
  })

  it('uses regrouped invoice strategy when payInAdvance + non-invoiceable + regroup=invoice', () => {
    render(
      <UsageChargeInfo
        charge={buildCharge({
          payInAdvance: true,
          invoiceable: false,
          regroupPaidFees: RegroupPaidFeesEnum.Invoice,
        })}
        currency={CurrencyEnum.Usd}
        planInterval={PlanInterval.Monthly}
        planTaxes={[]}
      />,
    )
    expect(screen.getByText('text_66968fba80f8f89a8aefdec0')).toBeInTheDocument()
  })

  it('uses plan taxes when charge has no taxes', () => {
    render(
      <UsageChargeInfo
        charge={buildCharge({ taxes: [] })}
        currency={CurrencyEnum.Usd}
        planInterval={PlanInterval.Monthly}
        planTaxes={[{ __typename: 'Tax', id: 't1', name: 'VAT', code: 'vat', rate: 20 } as never]}
      />,
    )
    expect(screen.getByText(/VAT/)).toBeInTheDocument()
  })

  it('uses succeeding-month strategy when payInAdvance + non-invoiceable + regroup is null', () => {
    render(
      <UsageChargeInfo
        charge={buildCharge({
          payInAdvance: true,
          invoiceable: false,
          regroupPaidFees: null,
        })}
        currency={CurrencyEnum.Usd}
        planInterval={PlanInterval.Monthly}
        planTaxes={[]}
      />,
    )
    expect(screen.getByText('text_6682c52081acea9052074686')).toBeInTheDocument()
  })

  it('uses "Invoiceable" row for recurring billable metrics', () => {
    render(
      <UsageChargeInfo
        charge={buildCharge({
          invoiceable: false,
          billableMetric: {
            __typename: 'BillableMetric',
            id: 'bm_recurring',
            name: 'Active users',
            code: 'active_users',
            recurring: true,
            filters: [],
          } as never,
        })}
        currency={CurrencyEnum.Usd}
        planInterval={PlanInterval.Monthly}
        planTaxes={[]}
      />,
    )
    // "Invoiceable" label key (recurring 4th row)
    expect(screen.getByText('text_646e2d0cc536351b62ba6f16')).toBeInTheDocument()
    // "Invoicing strategy" label key (metered 4th row) must NOT appear
    expect(screen.queryByText('text_6682c52081acea90520744ca')).not.toBeInTheDocument()
    // The yes/no value for invoiceable=false (may appear more than once due to prorated row)
    expect(screen.getAllByText('text_65251f4cd55aeb004e5aa5ef').length).toBeGreaterThanOrEqual(1)
  })

  it('uses "Invoicing strategy" row for non-recurring (metered) billable metrics', () => {
    render(
      <UsageChargeInfo
        charge={buildCharge({
          billableMetric: {
            __typename: 'BillableMetric',
            id: 'bm_metered',
            name: 'API calls',
            code: 'api_calls',
            recurring: false,
            filters: [],
          } as never,
        })}
        currency={CurrencyEnum.Usd}
        planInterval={PlanInterval.Monthly}
        planTaxes={[]}
      />,
    )
    expect(screen.getByText('text_6682c52081acea90520744ca')).toBeInTheDocument()
    expect(screen.queryByText('text_646e2d0cc536351b62ba6f16')).not.toBeInTheDocument()
  })

  it('uses charge.taxes when present, ignoring plan taxes', () => {
    render(
      <UsageChargeInfo
        charge={buildCharge({
          taxes: [{ __typename: 'Tax', id: 't_gst', name: 'GST', code: 'gst', rate: 10 } as never],
        })}
        currency={CurrencyEnum.Usd}
        planInterval={PlanInterval.Monthly}
        planTaxes={[
          { __typename: 'Tax', id: 't_vat', name: 'VAT', code: 'vat', rate: 20 } as never,
        ]}
      />,
    )
    expect(screen.getByText(/GST/)).toBeInTheDocument()
    expect(screen.queryByText(/VAT/)).not.toBeInTheDocument()
  })
})

const driftCharge = {
  id: 'c1',
  chargeModel: ChargeModelEnum.Standard,
  billableMetric: { id: 'bm1', name: 'BM', filters: [{ key: 'region', values: ['v0', 'v1'] }] },
  filters: [
    { invoiceDisplayName: 'A', values: { region: ['v0'] }, properties: {} },
    { invoiceDisplayName: 'B', values: { region: ['v1'] }, properties: {} },
  ],
} as unknown as UsageChargeInfoCharge

describe('UsageChargeInfo filters virtualization', () => {
  beforeEach(() => {
    capturedVirtualList.props = undefined
  })

  it('renders the filter list through VirtualFilterList with every filter', () => {
    render(<UsageChargeInfo charge={driftCharge} currency={CurrencyEnum.Usd} />)
    expect(capturedVirtualList.props?.items).toHaveLength(2)
  })
})
