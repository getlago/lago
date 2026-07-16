import {
  addOnFeeMock,
  addonMockFormatedForEstimate,
  feeMockFormatedForEstimate,
  feesMock,
} from '~/components/creditNote/__tests__/fixtures'
import { CreditTypeEnum } from '~/components/creditNote/types'
import {
  buildCreditNoteFees,
  buildInitialPayBack,
  canCreateCreditNote,
  createCreditNoteForInvoiceButtonProps,
  creditNoteFormCalculationCalculation,
  CreditNoteFormCalculationCalculationProps,
  creditNoteFormHasAtLeastOneFeeChecked,
  CreditNoteType,
  formatCreditNoteTypesForDisplay,
  getCreditNoteTypes,
  getPayBackFields,
  hasCreditableAmount,
  hasCreditableOrRefundableAmount,
  hasOffsettableAmount,
  hasRefundableAmount,
  isCreditNoteCreationDisabled,
} from '~/components/creditNote/utils'
import {
  CurrencyEnum,
  InvoiceForCreditNoteFormCalculationFragment,
  InvoiceTypeEnum,
} from '~/generated/graphql'

const prepare = ({
  addonFees = undefined,
  fees = undefined,
  hasError = false,
  currency = CurrencyEnum.Eur,
}: Partial<CreditNoteFormCalculationCalculationProps> = {}) => {
  const { feeForEstimate } = creditNoteFormCalculationCalculation({
    addonFees,
    fees,
    hasError,
    currency,
  })

  return { feeForEstimate }
}

describe('creditNoteFormCalculationCalculation', () => {
  describe('GIVEN hasError is true', () => {
    it('THEN should return undefined for feeForEstimate', () => {
      const { feeForEstimate } = prepare({ hasError: true })

      expect(feeForEstimate).toBeUndefined()
    })
  })

  describe('GIVEN fees are provided', () => {
    it('THEN should return fees for estimate', () => {
      const { feeForEstimate } = prepare({ fees: feesMock })

      expect(feeForEstimate).toEqual(feeMockFormatedForEstimate)
    })
  })

  describe('GIVEN addonFees are provided', () => {
    it('THEN should return addonFees for estimate', () => {
      const { feeForEstimate } = prepare({ addonFees: addOnFeeMock })

      expect(feeForEstimate).toEqual(addonMockFormatedForEstimate)
    })
  })
})

describe('creditNoteFormHasAtLeastOneFeeChecked', () => {
  describe('GIVEN addOnFee is present', () => {
    it('WHEN at least one addon fee is checked THEN should return true', () => {
      const formValues = {
        addOnFee: [
          { id: '1', checked: true, maxAmount: 100, name: 'Test Addon 1', value: 50 },
          { id: '2', checked: false, maxAmount: 200, name: 'Test Addon 2', value: 75 },
        ],
      }

      expect(creditNoteFormHasAtLeastOneFeeChecked(formValues)).toBe(true)
    })

    it('WHEN no addon fees are checked THEN should return false', () => {
      const formValues = {
        addOnFee: [
          { id: '1', checked: false, maxAmount: 100, name: 'Test Addon 1', value: 50 },
          { id: '2', checked: false, maxAmount: 200, name: 'Test Addon 2', value: 75 },
        ],
      }

      expect(creditNoteFormHasAtLeastOneFeeChecked(formValues)).toBe(false)
    })

    it('WHEN addOnFee array is empty THEN should return false', () => {
      const formValues = { addOnFee: [] }

      expect(creditNoteFormHasAtLeastOneFeeChecked(formValues)).toBe(false)
    })
  })

  describe('GIVEN creditFee is present (and no addOnFee)', () => {
    it('WHEN at least one credit fee is checked THEN should return true', () => {
      const formValues = {
        creditFee: [
          { id: '1', checked: true, maxAmount: 100, name: 'Test Credit 1', value: 50 },
          { id: '2', checked: false, maxAmount: 200, name: 'Test Credit 2', value: 75 },
        ],
      }

      expect(creditNoteFormHasAtLeastOneFeeChecked(formValues)).toBe(true)
    })

    it('WHEN no credit fees are checked THEN should return false', () => {
      const formValues = {
        creditFee: [
          { id: '1', checked: false, maxAmount: 100, name: 'Test Credit 1', value: 50 },
          { id: '2', checked: false, maxAmount: 200, name: 'Test Credit 2', value: 75 },
        ],
      }

      expect(creditNoteFormHasAtLeastOneFeeChecked(formValues)).toBe(false)
    })

    it('WHEN creditFee array is empty THEN should return false', () => {
      const formValues = { creditFee: [] }

      expect(creditNoteFormHasAtLeastOneFeeChecked(formValues)).toBe(false)
    })
  })

  describe('GIVEN regular fees are present (and no addOnFee or creditFee)', () => {
    it('WHEN at least one regular fee is checked THEN should return true', () => {
      const formValues = {
        fees: {
          subscription1: {
            subscriptionName: 'Test Subscription',
            fees: [
              { id: '1', checked: true, maxAmount: 100, name: 'Test Fee 1', value: 50 },
              { id: '2', checked: false, maxAmount: 200, name: 'Test Fee 2', value: 75 },
            ],
          },
        },
      }

      expect(creditNoteFormHasAtLeastOneFeeChecked(formValues)).toBe(true)
    })

    it('WHEN no regular fees are checked THEN should return false', () => {
      const formValues = {
        fees: {
          subscription1: {
            subscriptionName: 'Test Subscription',
            fees: [
              { id: '1', checked: false, maxAmount: 100, name: 'Test Fee 1', value: 50 },
              { id: '2', checked: false, maxAmount: 200, name: 'Test Fee 2', value: 75 },
            ],
          },
        },
      }

      expect(creditNoteFormHasAtLeastOneFeeChecked(formValues)).toBe(false)
    })

    it('WHEN fees object is empty THEN should return false', () => {
      const formValues = { fees: {} }

      expect(creditNoteFormHasAtLeastOneFeeChecked(formValues)).toBe(false)
    })

    it('WHEN multiple subscriptions have at least one checked fee THEN should return true', () => {
      const formValues = {
        fees: {
          subscription1: {
            subscriptionName: 'Test Subscription 1',
            fees: [{ id: '1', checked: false, maxAmount: 100, name: 'Test Fee 1', value: 50 }],
          },
          subscription2: {
            subscriptionName: 'Test Subscription 2',
            fees: [{ id: '2', checked: true, maxAmount: 200, name: 'Test Fee 2', value: 75 }],
          },
        },
      }

      expect(creditNoteFormHasAtLeastOneFeeChecked(formValues)).toBe(true)
    })

    it('WHEN subscription has empty fees array THEN should return false', () => {
      const formValues = {
        fees: {
          subscription1: {
            subscriptionName: 'Test Subscription',
            fees: [],
          },
        },
      }

      expect(creditNoteFormHasAtLeastOneFeeChecked(formValues)).toBe(false)
    })
  })

  describe('GIVEN edge cases', () => {
    it('WHEN all fee types are undefined THEN should return false', () => {
      expect(creditNoteFormHasAtLeastOneFeeChecked({})).toBe(false)
    })

    it('WHEN all fee types are null/empty THEN should return false', () => {
      const formValues = {
        addOnFee: undefined,
        creditFee: undefined,
        fees: undefined,
      }

      expect(creditNoteFormHasAtLeastOneFeeChecked(formValues)).toBe(false)
    })

    it('WHEN addOnFee takes precedence over other fee types THEN should only check addOnFee', () => {
      const formValues = {
        addOnFee: [{ id: '1', checked: false, maxAmount: 100, name: 'Test Addon', value: 50 }],
        creditFee: [{ id: '2', checked: true, maxAmount: 200, name: 'Test Credit', value: 75 }],
        fees: {
          subscription1: {
            subscriptionName: 'Test Subscription',
            fees: [{ id: '3', checked: true, maxAmount: 300, name: 'Test Fee', value: 100 }],
          },
        },
      }

      // Should return false because addOnFee takes precedence and none are checked
      expect(creditNoteFormHasAtLeastOneFeeChecked(formValues)).toBe(false)
    })

    it('WHEN creditFee takes precedence over regular fees THEN should only check creditFee', () => {
      const formValues = {
        creditFee: [{ id: '2', checked: false, maxAmount: 200, name: 'Test Credit', value: 75 }],
        fees: {
          subscription1: {
            subscriptionName: 'Test Subscription',
            fees: [{ id: '3', checked: true, maxAmount: 300, name: 'Test Fee', value: 100 }],
          },
        },
      }

      // Should return false because creditFee takes precedence and none are checked
      expect(creditNoteFormHasAtLeastOneFeeChecked(formValues)).toBe(false)
    })
  })
})

describe('hasCreditableAmount', () => {
  it('should return true when creditableAmountCents > 0', () => {
    expect(hasCreditableAmount({ creditableAmountCents: '1000' })).toBe(true)
  })

  it('should return false when creditableAmountCents is 0', () => {
    expect(hasCreditableAmount({ creditableAmountCents: '0' })).toBe(false)
  })

  it('should return false when creditableAmountCents is undefined', () => {
    expect(hasCreditableAmount({})).toBe(false)
  })

  it('should return false when invoice is undefined', () => {
    expect(hasCreditableAmount(undefined)).toBe(false)
  })

  it('should return false when invoice is null', () => {
    expect(hasCreditableAmount(null)).toBe(false)
  })
})

describe('hasRefundableAmount', () => {
  it('should return true when refundableAmountCents > 0', () => {
    expect(hasRefundableAmount({ refundableAmountCents: '1000' })).toBe(true)
  })

  it('should return false when refundableAmountCents is 0', () => {
    expect(hasRefundableAmount({ refundableAmountCents: '0' })).toBe(false)
  })

  it('should return false when refundableAmountCents is undefined', () => {
    expect(hasRefundableAmount({})).toBe(false)
  })

  it('should return false when invoice is undefined', () => {
    expect(hasRefundableAmount(undefined)).toBe(false)
  })

  it('should return false when invoice is null', () => {
    expect(hasRefundableAmount(null)).toBe(false)
  })
})

describe('hasCreditableOrRefundableAmount', () => {
  it('should return true when only creditableAmountCents > 0', () => {
    expect(
      hasCreditableOrRefundableAmount({
        creditableAmountCents: '1000',
        refundableAmountCents: '0',
      }),
    ).toBe(true)
  })

  it('should return true when only refundableAmountCents > 0', () => {
    expect(
      hasCreditableOrRefundableAmount({
        creditableAmountCents: '0',
        refundableAmountCents: '1000',
      }),
    ).toBe(true)
  })

  it('should return true when both amounts > 0', () => {
    expect(
      hasCreditableOrRefundableAmount({
        creditableAmountCents: '1000',
        refundableAmountCents: '500',
      }),
    ).toBe(true)
  })

  it('should return false when both amounts are 0', () => {
    expect(
      hasCreditableOrRefundableAmount({
        creditableAmountCents: '0',
        refundableAmountCents: '0',
      }),
    ).toBe(false)
  })

  it('should return false when invoice is undefined', () => {
    expect(hasCreditableOrRefundableAmount(undefined)).toBe(false)
  })

  it('should return false when invoice is null', () => {
    expect(hasCreditableOrRefundableAmount(null)).toBe(false)
  })
})

describe('hasOffsettableAmount', () => {
  it('should return true when offsettableAmountCents > 0', () => {
    expect(hasOffsettableAmount({ offsettableAmountCents: '1000' })).toBe(true)
  })

  it('should return false when offsettableAmountCents is 0', () => {
    expect(hasOffsettableAmount({ offsettableAmountCents: '0' })).toBe(false)
  })

  it('should return false when offsettableAmountCents is undefined', () => {
    expect(hasOffsettableAmount({})).toBe(false)
  })

  it('should return false when invoice is undefined', () => {
    expect(hasOffsettableAmount(undefined)).toBe(false)
  })

  it('should return false when invoice is null', () => {
    expect(hasOffsettableAmount(null)).toBe(false)
  })
})

describe('canCreateCreditNote', () => {
  it('should return true when creditableAmountCents > 0', () => {
    expect(
      canCreateCreditNote({
        creditableAmountCents: '1000',
        refundableAmountCents: '0',
        offsettableAmountCents: '0',
      }),
    ).toBe(true)
  })

  it('should return true when refundableAmountCents > 0', () => {
    expect(
      canCreateCreditNote({
        creditableAmountCents: '0',
        refundableAmountCents: '1000',
        offsettableAmountCents: '0',
      }),
    ).toBe(true)
  })

  it('should return true when offsettableAmountCents > 0', () => {
    expect(
      canCreateCreditNote({
        creditableAmountCents: '0',
        refundableAmountCents: '0',
        offsettableAmountCents: '1000',
      }),
    ).toBe(true)
  })

  it('should return false when all amounts are 0', () => {
    expect(
      canCreateCreditNote({
        creditableAmountCents: '0',
        refundableAmountCents: '0',
        offsettableAmountCents: '0',
      }),
    ).toBe(false)
  })

  it('should return false when invoice is undefined', () => {
    expect(canCreateCreditNote(undefined)).toBe(false)
  })

  it('should return false when invoice is null', () => {
    expect(canCreateCreditNote(null)).toBe(false)
  })
})

describe('isCreditNoteCreationDisabled', () => {
  describe('GIVEN invoice has no amounts available', () => {
    it('THEN should return true', () => {
      expect(
        isCreditNoteCreationDisabled({
          creditableAmountCents: '0',
          refundableAmountCents: '0',
          offsettableAmountCents: '0',
        }),
      ).toBe(true)
    })
  })

  describe('GIVEN invoice has amounts available', () => {
    it('WHEN creditableAmountCents > 0 THEN should return false', () => {
      expect(
        isCreditNoteCreationDisabled({
          creditableAmountCents: '1000',
          refundableAmountCents: '0',
          offsettableAmountCents: '0',
        }),
      ).toBe(false)
    })

    it('WHEN refundableAmountCents > 0 THEN should return false', () => {
      expect(
        isCreditNoteCreationDisabled({
          creditableAmountCents: '0',
          refundableAmountCents: '1000',
          offsettableAmountCents: '0',
        }),
      ).toBe(false)
    })

    it('WHEN offsettableAmountCents > 0 THEN should return false', () => {
      expect(
        isCreditNoteCreationDisabled({
          creditableAmountCents: '0',
          refundableAmountCents: '0',
          offsettableAmountCents: '1000',
        }),
      ).toBe(false)
    })
  })

  describe('GIVEN invoice is undefined or null', () => {
    it('WHEN invoice is undefined THEN should return false', () => {
      expect(isCreditNoteCreationDisabled(undefined)).toBe(false)
    })

    it('WHEN invoice is null THEN should return false', () => {
      expect(isCreditNoteCreationDisabled(null)).toBe(false)
    })
  })
})

describe('createCreditNoteForInvoiceButtonProps', () => {
  describe('GIVEN invoice has no amounts available', () => {
    it('THEN should disable button', () => {
      const result = createCreditNoteForInvoiceButtonProps({
        creditableAmountCents: '0',
        refundableAmountCents: '0',
        offsettableAmountCents: '0',
      })

      expect(result.disabledIssueCreditNoteButton).toBe(true)
      expect(result.disabledIssueCreditNoteButtonLabel).toBe('text_1729082994964zccpjmtotdy')
    })
  })

  describe('GIVEN invoice has amounts available', () => {
    it('WHEN creditableAmountCents > 0 THEN should enable button', () => {
      const result = createCreditNoteForInvoiceButtonProps({
        creditableAmountCents: '1000',
        refundableAmountCents: '0',
        offsettableAmountCents: '0',
      })

      expect(result.disabledIssueCreditNoteButton).toBe(false)
      expect(result.disabledIssueCreditNoteButtonLabel).toBeFalsy()
    })

    it('WHEN refundableAmountCents > 0 THEN should enable button', () => {
      const result = createCreditNoteForInvoiceButtonProps({
        creditableAmountCents: '0',
        refundableAmountCents: '1000',
        offsettableAmountCents: '0',
      })

      expect(result.disabledIssueCreditNoteButton).toBe(false)
      expect(result.disabledIssueCreditNoteButtonLabel).toBeFalsy()
    })

    it('WHEN offsettableAmountCents > 0 THEN should enable button', () => {
      const result = createCreditNoteForInvoiceButtonProps({
        creditableAmountCents: '0',
        refundableAmountCents: '0',
        offsettableAmountCents: '1000',
      })

      expect(result.disabledIssueCreditNoteButton).toBe(false)
      expect(result.disabledIssueCreditNoteButtonLabel).toBeFalsy()
    })
  })

  describe('GIVEN prepaid credits invoice with terminated wallet', () => {
    it('WHEN disabled THEN should show terminatedWallet message', () => {
      const result = createCreditNoteForInvoiceButtonProps({
        invoiceType: InvoiceTypeEnum.Credit,
        associatedActiveWalletPresent: false,
        creditableAmountCents: '0',
        refundableAmountCents: '0',
        offsettableAmountCents: '0',
      })

      expect(result.disabledIssueCreditNoteButton).toBe(true)
      expect(result.disabledIssueCreditNoteButtonLabel).toBe('text_172908299496461z9ejmm2j7')
    })
  })
})

describe('getPayBackFields', () => {
  describe('GIVEN undefined payBack', () => {
    it('THEN should return all fields with show=false and empty values', () => {
      const result = getPayBackFields(undefined)

      expect(result.credit).toEqual({ path: '', value: 0, show: false })
      expect(result.refund).toEqual({ path: '', value: 0, show: false })
      expect(result.offset).toEqual({ path: '', value: 0, show: false })
    })
  })

  describe('GIVEN empty payBack array', () => {
    it('THEN should return all fields with show=false', () => {
      const result = getPayBackFields([])

      expect(result.credit.show).toBe(false)
      expect(result.refund.show).toBe(false)
      expect(result.offset.show).toBe(false)
    })
  })

  describe('GIVEN payBack with only credit', () => {
    it('THEN should return credit with show=true and correct path', () => {
      const payBack = [{ type: CreditTypeEnum.credit, value: 50 }]

      const result = getPayBackFields(payBack)

      expect(result.credit).toEqual({ path: 'payBack.0.value', value: 50, show: true })
      expect(result.refund.show).toBe(false)
      expect(result.offset.show).toBe(false)
    })
  })

  describe('GIVEN payBack with credit and refund', () => {
    it('THEN should return correct paths based on array index', () => {
      const payBack = [
        { type: CreditTypeEnum.credit, value: 30 },
        { type: CreditTypeEnum.refund, value: 20 },
      ]

      const result = getPayBackFields(payBack)

      expect(result.credit).toEqual({ path: 'payBack.0.value', value: 30, show: true })
      expect(result.refund).toEqual({ path: 'payBack.1.value', value: 20, show: true })
      expect(result.offset.show).toBe(false)
    })
  })

  describe('GIVEN payBack with all three types', () => {
    it('THEN should return all fields with show=true and correct paths', () => {
      const payBack = [
        { type: CreditTypeEnum.credit, value: 30 },
        { type: CreditTypeEnum.refund, value: 20 },
        { type: CreditTypeEnum.offset, value: 10 },
      ]

      const result = getPayBackFields(payBack)

      expect(result.credit).toEqual({ path: 'payBack.0.value', value: 30, show: true })
      expect(result.refund).toEqual({ path: 'payBack.1.value', value: 20, show: true })
      expect(result.offset).toEqual({ path: 'payBack.2.value', value: 10, show: true })
    })
  })

  describe('GIVEN payBack with undefined values', () => {
    it('THEN should default value to 0', () => {
      const payBack = [
        { type: CreditTypeEnum.credit, value: undefined },
        { type: CreditTypeEnum.refund, value: undefined },
      ]

      const result = getPayBackFields(payBack)

      expect(result.credit.value).toBe(0)
      expect(result.refund.value).toBe(0)
    })
  })

  describe('GIVEN payBack with different order', () => {
    it('THEN should find correct index regardless of order', () => {
      const payBack = [
        { type: CreditTypeEnum.offset, value: 10 },
        { type: CreditTypeEnum.credit, value: 30 },
      ]

      const result = getPayBackFields(payBack)

      expect(result.credit).toEqual({ path: 'payBack.1.value', value: 30, show: true })
      expect(result.offset).toEqual({ path: 'payBack.0.value', value: 10, show: true })
      expect(result.refund.show).toBe(false)
    })
  })
})

describe('buildInitialPayBack', () => {
  const createMockInvoice = (
    overrides: Partial<InvoiceForCreditNoteFormCalculationFragment> = {},
  ): InvoiceForCreditNoteFormCalculationFragment =>
    ({
      id: 'invoice-1',
      totalAmountCents: '10000',
      totalPaidAmountCents: '10000',
      totalDueAmountCents: '0',
      paymentDisputeLostAt: null,
      currency: CurrencyEnum.Usd,
      invoiceType: InvoiceTypeEnum.Subscription,
      ...overrides,
    }) as InvoiceForCreditNoteFormCalculationFragment

  describe('GIVEN undefined invoice', () => {
    it('THEN should return only credit type with value undefined', () => {
      const result = buildInitialPayBack(undefined)

      expect(result).toEqual([{ type: CreditTypeEnum.credit, value: undefined }])
    })
  })

  describe('GIVEN null invoice', () => {
    it('THEN should return only credit type with value undefined', () => {
      const result = buildInitialPayBack(null)

      expect(result).toEqual([{ type: CreditTypeEnum.credit, value: undefined }])
    })
  })

  describe('GIVEN fully paid invoice', () => {
    it('WHEN no dispute lost THEN should include credit and refund with value undefined', () => {
      const invoice = createMockInvoice({
        totalPaidAmountCents: '10000',
        totalDueAmountCents: '0',
        paymentDisputeLostAt: null,
      })

      const result = buildInitialPayBack(invoice)

      expect(result).toEqual([
        { type: CreditTypeEnum.credit, value: undefined },
        { type: CreditTypeEnum.refund, value: undefined },
      ])
    })

    it('WHEN dispute lost THEN should include only credit (no refund) with value undefined', () => {
      const invoice = createMockInvoice({
        totalPaidAmountCents: '10000',
        totalDueAmountCents: '0',
        paymentDisputeLostAt: '2024-01-01',
      })

      const result = buildInitialPayBack(invoice)

      expect(result).toEqual([{ type: CreditTypeEnum.credit, value: undefined }])
    })
  })

  describe('GIVEN partially paid invoice', () => {
    it('WHEN no dispute lost THEN should include credit, refund, and offset with value undefined', () => {
      const invoice = createMockInvoice({
        totalPaidAmountCents: '5000',
        totalDueAmountCents: '5000',
        paymentDisputeLostAt: null,
      })

      const result = buildInitialPayBack(invoice)

      expect(result).toEqual([
        { type: CreditTypeEnum.credit, value: undefined },
        { type: CreditTypeEnum.refund, value: undefined },
        { type: CreditTypeEnum.offset, value: undefined },
      ])
    })

    it('WHEN dispute lost THEN should include credit and offset (no refund) with value undefined', () => {
      const invoice = createMockInvoice({
        totalPaidAmountCents: '5000',
        totalDueAmountCents: '5000',
        paymentDisputeLostAt: '2024-01-01',
      })

      const result = buildInitialPayBack(invoice)

      expect(result).toEqual([
        { type: CreditTypeEnum.credit, value: undefined },
        { type: CreditTypeEnum.offset, value: undefined },
      ])
    })
  })

  describe('GIVEN unpaid invoice', () => {
    it('THEN should include credit and offset (no refund) with value undefined', () => {
      const invoice = createMockInvoice({
        totalPaidAmountCents: '0',
        totalDueAmountCents: '10000',
        paymentDisputeLostAt: null,
      })

      const result = buildInitialPayBack(invoice)

      expect(result).toEqual([
        { type: CreditTypeEnum.credit, value: undefined },
        { type: CreditTypeEnum.offset, value: undefined },
      ])
    })
  })
})

describe('getCreditNoteTypes', () => {
  describe('GIVEN only creditAmountCents > 0', () => {
    it('THEN should return [CREDIT]', () => {
      const result = getCreditNoteTypes({
        creditAmountCents: '1000',
        refundAmountCents: '0',
        offsetAmountCents: '0',
      })

      expect(result).toEqual([CreditNoteType.CREDIT])
    })
  })

  describe('GIVEN only refundAmountCents > 0', () => {
    it('THEN should return [REFUND]', () => {
      const result = getCreditNoteTypes({
        creditAmountCents: '0',
        refundAmountCents: '1000',
        offsetAmountCents: '0',
      })

      expect(result).toEqual([CreditNoteType.REFUND])
    })
  })

  describe('GIVEN only offsetAmountCents > 0', () => {
    it('THEN should return [ON_INVOICE]', () => {
      const result = getCreditNoteTypes({
        creditAmountCents: '0',
        refundAmountCents: '0',
        offsetAmountCents: '1000',
      })

      expect(result).toEqual([CreditNoteType.ON_INVOICE])
    })
  })

  describe('GIVEN creditAmountCents and refundAmountCents > 0', () => {
    it('THEN should return [CREDIT, REFUND]', () => {
      const result = getCreditNoteTypes({
        creditAmountCents: '1000',
        refundAmountCents: '500',
        offsetAmountCents: '0',
      })

      expect(result).toEqual([CreditNoteType.CREDIT, CreditNoteType.REFUND])
    })
  })

  describe('GIVEN creditAmountCents and offsetAmountCents > 0', () => {
    it('THEN should return [CREDIT, ON_INVOICE]', () => {
      const result = getCreditNoteTypes({
        creditAmountCents: '1000',
        refundAmountCents: '0',
        offsetAmountCents: '500',
      })

      expect(result).toEqual([CreditNoteType.CREDIT, CreditNoteType.ON_INVOICE])
    })
  })

  describe('GIVEN refundAmountCents and offsetAmountCents > 0', () => {
    it('THEN should return [ON_INVOICE, REFUND]', () => {
      const result = getCreditNoteTypes({
        creditAmountCents: '0',
        refundAmountCents: '1000',
        offsetAmountCents: '500',
      })

      expect(result).toEqual([CreditNoteType.ON_INVOICE, CreditNoteType.REFUND])
    })
  })

  describe('GIVEN all three amounts > 0', () => {
    it('THEN should return [CREDIT, ON_INVOICE, REFUND]', () => {
      const result = getCreditNoteTypes({
        creditAmountCents: '1000',
        refundAmountCents: '500',
        offsetAmountCents: '300',
      })

      expect(result).toEqual([
        CreditNoteType.CREDIT,
        CreditNoteType.ON_INVOICE,
        CreditNoteType.REFUND,
      ])
    })
  })

  describe('GIVEN all amounts are 0', () => {
    it('THEN should return empty array', () => {
      const result = getCreditNoteTypes({
        creditAmountCents: '0',
        refundAmountCents: '0',
        offsetAmountCents: '0',
      })

      expect(result).toEqual([])
    })
  })
})

describe('formatCreditNoteTypesForDisplay', () => {
  describe('GIVEN empty array', () => {
    it('THEN should return empty string', () => {
      expect(formatCreditNoteTypesForDisplay([])).toBe('')
    })
  })

  describe('GIVEN single type', () => {
    it('THEN should return the type as-is', () => {
      expect(formatCreditNoteTypesForDisplay(['Credit'])).toBe('Credit')
    })
  })

  describe('GIVEN two types', () => {
    it('THEN should format as "First & second"', () => {
      expect(formatCreditNoteTypesForDisplay(['Credit', 'Refund'])).toBe('Credit & refund')
    })

    it('WHEN types have different casing THEN should normalize to lowercase except first', () => {
      expect(formatCreditNoteTypesForDisplay(['CREDIT', 'REFUND'])).toBe('Credit & refund')
    })
  })

  describe('GIVEN three types', () => {
    it('THEN should format as "First, second & third"', () => {
      expect(formatCreditNoteTypesForDisplay(['Credit', 'Offset', 'Refund'])).toBe(
        'Credit, offset & refund',
      )
    })
  })

  describe('GIVEN four types', () => {
    it('THEN should format as "First, second, third & fourth"', () => {
      expect(formatCreditNoteTypesForDisplay(['Type1', 'Type2', 'Type3', 'Type4'])).toBe(
        'Type1, type2, type3 & type4',
      )
    })
  })
})

describe('buildCreditNoteFees', () => {
  const createMockFee = (
    overrides: Partial<{
      id: string
      amountCurrency: CurrencyEnum
      invoiceName: string | null
      itemName: string | null
      creditableAmountCents: string
      offsettableAmountCents: string
      appliedTaxes: Array<{ id: string; taxName: string; taxRate: number }> | null
    }> = {},
  ) => ({
    id: 'fee-1',
    amountCurrency: CurrencyEnum.Eur,
    invoiceName: 'Test Fee',
    itemName: 'Item Name',
    creditableAmountCents: '1000',
    offsettableAmountCents: '500',
    appliedTaxes: [{ id: 'tax-1', taxName: 'VAT', taxRate: 20 }],
    ...overrides,
  })

  describe('GIVEN undefined fees', () => {
    it('THEN should return empty array', () => {
      expect(buildCreditNoteFees(undefined, true)).toEqual([])
    })
  })

  describe('GIVEN null fees', () => {
    it('THEN should return empty array', () => {
      expect(buildCreditNoteFees(null, true)).toEqual([])
    })
  })

  describe('GIVEN empty fees array', () => {
    it('THEN should return empty array', () => {
      expect(buildCreditNoteFees([], true)).toEqual([])
    })
  })

  describe('GIVEN hasCreditableOrRefundableAmount is true', () => {
    it('THEN should use creditableAmountCents', () => {
      const fees = [createMockFee()]

      const result = buildCreditNoteFees(fees, true)

      expect(result).toHaveLength(1)
      expect(result[0]).toEqual({
        id: 'fee-1',
        checked: true,
        value: 10, // 1000 cents = 10 EUR
        name: 'Test Fee',
        maxAmount: 1000,
        appliedTaxes: [{ id: 'tax-1', taxName: 'VAT', taxRate: 20 }],
        isReadOnly: false,
      })
    })

    it('WHEN creditableAmountCents is 0 THEN should skip the fee', () => {
      const fees = [createMockFee({ creditableAmountCents: '0' })]

      const result = buildCreditNoteFees(fees, true)

      expect(result).toEqual([])
    })
  })

  describe('GIVEN hasCreditableOrRefundableAmount is false', () => {
    it('THEN should use offsettableAmountCents and set isReadOnly to true', () => {
      const fees = [createMockFee()]

      const result = buildCreditNoteFees(fees, false)

      expect(result).toHaveLength(1)
      expect(result[0]).toEqual({
        id: 'fee-1',
        checked: true,
        value: 5, // 500 cents = 5 EUR
        name: 'Test Fee',
        maxAmount: 500,
        appliedTaxes: [{ id: 'tax-1', taxName: 'VAT', taxRate: 20 }],
        isReadOnly: true,
      })
    })

    it('WHEN offsettableAmountCents is 0 THEN should skip the fee', () => {
      const fees = [createMockFee({ offsettableAmountCents: '0' })]

      const result = buildCreditNoteFees(fees, false)

      expect(result).toEqual([])
    })
  })

  describe('GIVEN fee with no invoiceName', () => {
    it('THEN should use itemName as fallback', () => {
      const fees = [createMockFee({ invoiceName: null })]

      const result = buildCreditNoteFees(fees, true)

      expect(result[0].name).toBe('Item Name')
    })
  })

  describe('GIVEN fee with no invoiceName and no itemName', () => {
    it('THEN should use empty string', () => {
      const fees = [createMockFee({ invoiceName: null, itemName: null })]

      const result = buildCreditNoteFees(fees, true)

      expect(result[0].name).toBe('')
    })
  })

  describe('GIVEN fee with no appliedTaxes', () => {
    it('THEN should use empty array', () => {
      const fees = [createMockFee({ appliedTaxes: null })]

      const result = buildCreditNoteFees(fees, true)

      expect(result[0].appliedTaxes).toEqual([])
    })
  })

  describe('GIVEN multiple fees', () => {
    it('THEN should convert all valid fees', () => {
      const fees = [
        createMockFee({ id: 'fee-1', creditableAmountCents: '1000' }),
        createMockFee({ id: 'fee-2', creditableAmountCents: '2000' }),
        createMockFee({ id: 'fee-3', creditableAmountCents: '0' }), // Should be skipped
      ]

      const result = buildCreditNoteFees(fees, true)

      expect(result).toHaveLength(2)
      expect(result[0].id).toBe('fee-1')
      expect(result[1].id).toBe('fee-2')
    })
  })
})
