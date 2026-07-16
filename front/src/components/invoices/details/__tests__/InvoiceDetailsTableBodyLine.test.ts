import { calculateIfDetailsShouldBeDisplayed } from '~/components/invoices/details/InvoiceDetailsTableBodyLine'
import { TExtendedRemainingFee } from '~/core/formats/formatInvoiceItemsMap'
import { AdjustedFeeTypeEnum, ChargeModelEnum, FeeTypesEnum } from '~/generated/graphql'

// Stub the drawer hook so the transitive `drawerStack.ts` (Vite-only `import.meta.hot`)
// is never loaded when this helper-only test imports BodyLine.
jest.mock('~/components/invoices/details/ViewFeeDetailsDrawer', () => ({
  useViewFeeDetailsDrawer: () => ({ open: jest.fn(), close: jest.fn() }),
}))

type TPrepare = {
  fee?: TExtendedRemainingFee
  isTrueUpFee?: boolean
  canHaveUnitPrice?: boolean
}
const prepare = ({ fee, isTrueUpFee = false, canHaveUnitPrice = true }: TPrepare) => {
  return calculateIfDetailsShouldBeDisplayed(fee, isTrueUpFee, canHaveUnitPrice)
}

describe('calculateIfDetailsShouldBeDisplayed', () => {
  it('should return false if fee is undefined', () => {
    const result = prepare({ fee: undefined })

    expect(result).toBe(false)
  })

  it('should return false if isTrueUpFee is true', () => {
    const fee = {
      amountCents: 100,
      amountCurrency: 'USD',
    } as unknown as TExtendedRemainingFee
    const result = prepare({ fee, isTrueUpFee: true })

    expect(result).toBe(false)
  })

  it('should return false if canHaveUnitPrice is false', () => {
    const fee = {
      amountCents: 100,
      amountCurrency: 'USD',
    } as unknown as TExtendedRemainingFee
    const result = prepare({ fee, canHaveUnitPrice: false })

    expect(result).toBe(false)
  })

  it('should return false if fee.adjustedFeeType is AdjustedAmount', () => {
    const fee = {
      adjustedFeeType: AdjustedFeeTypeEnum.AdjustedAmount,
    } as unknown as TExtendedRemainingFee
    const result = prepare({ fee })

    expect(result).toBe(false)
  })

  it('should return false if fee.metadata.isSubscriptionFee is true', () => {
    const fee = {
      metadata: { isSubscriptionFee: true },
    } as unknown as TExtendedRemainingFee
    const result = prepare({ fee })

    expect(result).toBe(false)
  })

  it('should return false if fee.charge.chargeModel is Standard', () => {
    const fee = {
      charge: { chargeModel: ChargeModelEnum.Standard },
    } as unknown as TExtendedRemainingFee
    const result = prepare({ fee })

    expect(result).toBe(false)
  })

  it('should return false if fee.feeType is AddOn or Credit', () => {
    let fee = { feeType: FeeTypesEnum.AddOn } as unknown as TExtendedRemainingFee
    const result = prepare({ fee })

    expect(result).toBe(false)
    fee = { feeType: FeeTypesEnum.Credit } as unknown as TExtendedRemainingFee
    expect(result).toBe(false)
  })

  it('should return false if fee is in advance', () => {
    const fee = {
      charge: { payInAdvance: true },
    } as unknown as TExtendedRemainingFee
    const result = prepare({ fee })

    expect(result).toBe(false)
  })

  it('should return false if fee is recurring', () => {
    const fee = {
      charge: { billableMetric: { recurring: true } },
    } as unknown as TExtendedRemainingFee
    const result = prepare({ fee })

    expect(result).toBe(false)
  })

  it('should return true for graduated full charges', () => {
    const fee = {
      charge: { chargeModel: ChargeModelEnum.Graduated, prorated: false },
    } as unknown as TExtendedRemainingFee
    const result = prepare({ fee })

    expect(result).toBe(true)
  })

  it('should return true for volume charges', () => {
    const fee = {
      charge: { chargeModel: ChargeModelEnum.Volume },
    } as unknown as TExtendedRemainingFee
    const result = prepare({ fee })

    expect(result).toBe(true)
  })

  it('should return true for package charges', () => {
    const fee = {
      charge: { chargeModel: ChargeModelEnum.Package },
    } as unknown as TExtendedRemainingFee
    const result = prepare({ fee })

    expect(result).toBe(true)
  })

  it('should return true for percentage charges', () => {
    const fee = {
      charge: { chargeModel: ChargeModelEnum.Percentage },
    } as unknown as TExtendedRemainingFee
    const result = prepare({ fee })

    expect(result).toBe(true)
  })

  it('should return true for graduated percentage charges', () => {
    const fee = {
      charge: { chargeModel: ChargeModelEnum.GraduatedPercentage },
    } as unknown as TExtendedRemainingFee
    const result = prepare({ fee })

    expect(result).toBe(true)
  })

  it('should return true if fee is in arrears', () => {
    const fee = {
      charge: { payInAdvance: false },
    } as unknown as TExtendedRemainingFee
    const result = prepare({ fee })

    expect(result).toBe(false)
  })

  it('should return true if fee is valid advance recurring volume charge', () => {
    const fee = {
      amountDetails: { flatUnitAmount: '1' },
      charge: {
        chargeModel: ChargeModelEnum.Volume,
        payInAdvance: true,
        billableMetric: { recurring: true },
      },
    } as unknown as TExtendedRemainingFee
    const result = prepare({ fee })

    expect(result).toBe(true)
  })

  it('should return true if fee is valid advance recurring package charge', () => {
    const fee = {
      amountDetails: { freeUnits: '1' },
      charge: {
        chargeModel: ChargeModelEnum.Package,
        payInAdvance: true,
        billableMetric: { recurring: true },
      },
    } as unknown as TExtendedRemainingFee
    const result = prepare({ fee })

    expect(result).toBe(true)
  })

  it('should return true if fee is valid advance recurring percentage charge', () => {
    const fee = {
      amountDetails: { fixedFeeUnitAmount: '1' },
      charge: {
        chargeModel: ChargeModelEnum.Percentage,
        payInAdvance: true,
        billableMetric: { recurring: true },
      },
    } as unknown as TExtendedRemainingFee
    const result = prepare({ fee })

    expect(result).toBe(true)
  })

  it('should return true if fee is valid advance recurring graduated charge', () => {
    const fee = {
      amountDetails: { graduatedRanges: [{ toValue: 1 }] },
      charge: {
        chargeModel: ChargeModelEnum.Graduated,
        payInAdvance: true,
        billableMetric: { recurring: true },
      },
    } as unknown as TExtendedRemainingFee
    const result = prepare({ fee })

    expect(result).toBe(true)
  })

  it('should return true if fee is valid advance recurring graduated percentage charge', () => {
    const fee = {
      amountDetails: { graduatedPercentageRanges: [{ toValue: 1 }] },
      charge: {
        chargeModel: ChargeModelEnum.GraduatedPercentage,
        payInAdvance: true,
        billableMetric: { recurring: true },
      },
    } as unknown as TExtendedRemainingFee
    const result = prepare({ fee })

    expect(result).toBe(true)
  })
})
