import {
  invoiceSubAllFilterChargesSelected,
  invoiceSubBothChargesAndFixedCharges,
  invoiceSubOnlyFixedCharges,
  invoiceSubThreeChargesMultipleFilters,
  invoiceSubTwoChargeOneFilter,
  invoiceSubTwoChargeOneFilterDefaultAlreadySelected,
  invoiceSubWithAdjustedFeesTrue,
  invoiceSubWithFiltersForOverride,
  overrideFeesWithFilters,
  overrideFeesWithMixedAdjustedStatus,
} from './fixture'

import {
  getChargesComboboxDataFromInvoiceSubscription,
  getChargesFiltersComboboxDataFromInvoiceSubscription,
} from '../utils'

describe('Invoices >  Details > Utils', () => {
  describe('getChargesComboboxDataFromInvoiceSubscription', () => {
    it('returns an empty array of no invoiceSubscription passed', () => {
      const result = getChargesComboboxDataFromInvoiceSubscription({
        chargesGroupLabel: 'Usage-based charges',
        fixedChargesGroupLabel: 'Fixed charges',
        subscription: undefined,
      })

      expect(result).toEqual([])
    })

    it('returns correct Combobox Data for two charges and one with filters', () => {
      const result = getChargesComboboxDataFromInvoiceSubscription({
        chargesGroupLabel: 'Usage-based charges',
        fixedChargesGroupLabel: 'Fixed charges',
        subscription: invoiceSubTwoChargeOneFilter,
        overrideFees: invoiceSubTwoChargeOneFilter.fees,
      })

      expect(result).toEqual([
        {
          description: 'count_bm',
          label: 'Count BM',
          value: 'c53a7a35-fa5e-407b-bf87-2b96dc1dead2',
          group: 'Usage-based charges',
        },
        {
          description: 'bm_with_filters',
          label: 'bm with filters',
          value: '5de3ebeb-1d6d-4aa1-8866-1fffc948224a',
          group: 'Usage-based charges',
        },
      ])
    })

    it('returns correct Combobox Data for 3 charges and one with multiple filters', () => {
      const result = getChargesComboboxDataFromInvoiceSubscription({
        chargesGroupLabel: 'Usage-based charges',
        fixedChargesGroupLabel: 'Fixed charges',
        subscription: invoiceSubThreeChargesMultipleFilters,
        overrideFees: invoiceSubThreeChargesMultipleFilters.fees,
      })

      expect(result).toEqual([
        {
          description: 'count_bm',
          label: 'Count BM',
          value: 'c53a7a35-fa5e-407b-bf87-2b96dc1dead2',
          group: 'Usage-based charges',
        },
        {
          description: 'bm_with_filters',
          label: 'bm with filters',
          value: '5de3ebeb-1d6d-4aa1-8866-1fffc948224a',
          group: 'Usage-based charges',
        },
        {
          description: 'sum_bm',
          label: 'Sum BM',
          value: '9191b741-ee76-4cae-b9e2-c34f2f0d7b15',
          group: 'Usage-based charges',
        },
      ])
    })

    it('returns correct Combobox Data if all charge with filter have fees', () => {
      const result = getChargesComboboxDataFromInvoiceSubscription({
        chargesGroupLabel: 'Usage-based charges',
        fixedChargesGroupLabel: 'Fixed charges',
        subscription: invoiceSubAllFilterChargesSelected,
        overrideFees: invoiceSubAllFilterChargesSelected.fees,
      })

      expect(result).toEqual([
        {
          description: 'count_bm',
          label: 'Count BM',
          value: '332a641c-d82d-4c9e-bfbe-298b9fc2d1de',
          group: 'Usage-based charges',
        },
        {
          description: 'sum_bm',
          label: 'Sum BM',
          value: '6ca2019f-af61-45e1-a58e-b616ad5615ef',
          group: 'Usage-based charges',
        },
      ])
    })

    it('returns correct Combobox Data for fixed charges only', () => {
      const result = getChargesComboboxDataFromInvoiceSubscription({
        chargesGroupLabel: 'Usage-based charges',
        fixedChargesGroupLabel: 'Fixed charges',
        subscription: invoiceSubOnlyFixedCharges,
        overrideFees: invoiceSubOnlyFixedCharges.fees,
      })

      expect(result).toEqual([
        {
          description: 'monthly_support',
          label: 'Monthly Support',
          value: 'fc2b3c4d-5e6f-7g8h-9i0j-1k2l3m4n5o6p',
          group: 'Fixed charges',
        },
      ])
    })

    it('returns correct Combobox Data for both charges and fixed charges', () => {
      const result = getChargesComboboxDataFromInvoiceSubscription({
        chargesGroupLabel: 'Usage-based charges',
        fixedChargesGroupLabel: 'Fixed charges',
        subscription: invoiceSubBothChargesAndFixedCharges,
        overrideFees: invoiceSubBothChargesAndFixedCharges.fees,
      })

      expect(result).toEqual([
        {
          description: 'enterprise_license',
          label: 'License Fee',
          value: 'fc4d5e6f-7g8h-9i0j-1k2l-3m4n5o6p7q8r',
          group: 'Fixed charges',
        },
      ])
    })
  })

  describe('getChargesFiltersComboboxDataFromInvoiceSubscription', () => {
    it('returns an empty array of no invoiceSubscription passed', () => {
      const result = getChargesFiltersComboboxDataFromInvoiceSubscription({
        defaultFilterOptionLabel: 'defaultFilterOptionLabel',
        subscription: undefined,
        selectedChargeId: 'selectedChargeId',
      })

      expect(result).toEqual([])
    })

    it('returns an empty array of no selectedChargeId passed', () => {
      const result = getChargesFiltersComboboxDataFromInvoiceSubscription({
        defaultFilterOptionLabel: 'defaultFilterOptionLabel',
        subscription: invoiceSubTwoChargeOneFilter,
        selectedChargeId: undefined,
      })

      expect(result).toEqual([])
    })

    it('returns correct Combobox Data Filters for two charges and one with filters', () => {
      const result = getChargesFiltersComboboxDataFromInvoiceSubscription({
        defaultFilterOptionLabel: 'defaultFilterOptionLabel',
        subscription: invoiceSubTwoChargeOneFilter,
        selectedChargeId: '5de3ebeb-1d6d-4aa1-8866-1fffc948224a',
        overrideFees: invoiceSubTwoChargeOneFilter.fees,
      })

      expect(result).toEqual([
        {
          label: 'defaultFilterOptionLabel',
          value: '__ALL_FILTER_VALUES__',
        },
        {
          label: 'payment_type • asia',
          value: 'f10c88e6-bc95-4c1e-92fe-e0f94ac66571',
        },
      ])
    })

    it('returns correct Combobox Data Filters for two charges and one with filters while default filter already has a fee', () => {
      const result = getChargesFiltersComboboxDataFromInvoiceSubscription({
        defaultFilterOptionLabel: 'defaultFilterOptionLabel',
        subscription: invoiceSubTwoChargeOneFilterDefaultAlreadySelected,
        selectedChargeId: '5de3ebeb-1d6d-4aa1-8866-1fffc948224a',
        overrideFees: invoiceSubTwoChargeOneFilterDefaultAlreadySelected.fees,
      })

      expect(result).toEqual([
        {
          label: 'payment_type • asia',
          value: 'f10c88e6-bc95-4c1e-92fe-e0f94ac66571',
        },
      ])
    })

    it('returns correct Combobox Data Filters for 3 charges and one with multiple filters', () => {
      const result = getChargesFiltersComboboxDataFromInvoiceSubscription({
        defaultFilterOptionLabel: 'defaultFilterOptionLabel',
        subscription: invoiceSubThreeChargesMultipleFilters,
        selectedChargeId: '5de3ebeb-1d6d-4aa1-8866-1fffc948224a',
        overrideFees: invoiceSubThreeChargesMultipleFilters.fees,
      })

      expect(result).toEqual([
        {
          label: 'defaultFilterOptionLabel',
          value: '__ALL_FILTER_VALUES__',
        },
        {
          label: 'payment_type • asia',
          value: 'f10c88e6-bc95-4c1e-92fe-e0f94ac66571',
        },
      ])
    })

    it('returns correct Combobox Data Filters if all charge with filter have fees', () => {
      const result = getChargesFiltersComboboxDataFromInvoiceSubscription({
        defaultFilterOptionLabel: 'defaultFilterOptionLabel',
        subscription: invoiceSubAllFilterChargesSelected,
        selectedChargeId: '332a641c-d82d-4c9e-bfbe-298b9fc2d1de',
        overrideFees: invoiceSubAllFilterChargesSelected.fees,
      })

      expect(result).toEqual([])
    })
  })

  describe('excludes charges with any fee regardless of adjustedFee status', () => {
    describe('getChargesComboboxDataFromInvoiceSubscription', () => {
      it('excludes all charges that have fees, regardless of adjustedFee status', () => {
        const result = getChargesComboboxDataFromInvoiceSubscription({
          chargesGroupLabel: 'Usage-based charges',
          fixedChargesGroupLabel: 'Fixed charges',
          subscription: invoiceSubWithAdjustedFeesTrue,
          overrideFees: overrideFeesWithMixedAdjustedStatus,
        })

        // All charges with fees should be excluded, regardless of adjustedFee value
        // All 4 charges have fees, so none should appear
        expect(result).toEqual([])
      })

      it('allows all charges when overrideFees is empty array', () => {
        const result = getChargesComboboxDataFromInvoiceSubscription({
          chargesGroupLabel: 'Usage-based charges',
          fixedChargesGroupLabel: 'Fixed charges',
          subscription: invoiceSubWithAdjustedFeesTrue,
          overrideFees: [],
        })

        // With empty overrideFees, all charges should be available
        expect(result).toEqual([
          {
            description: 'adjusted_addon',
            label: 'Adjusted Fixed Charge',
            value: 'fixed-charge-adj-true',
            group: 'Fixed charges',
          },
          {
            description: 'not_adjusted_addon',
            label: 'Not Adjusted Fixed Charge',
            value: 'fixed-charge-not-adj',
            group: 'Fixed charges',
          },
          {
            description: 'adjusted_bm',
            label: 'Adjusted Charge',
            value: 'charge-adj-true-1',
            group: 'Usage-based charges',
          },
          {
            description: 'non_adjusted_bm',
            label: 'Non-Adjusted Charge',
            value: 'charge-adj-true-2',
            group: 'Usage-based charges',
          },
        ])
      })
    })

    describe('getChargesFiltersComboboxDataFromInvoiceSubscription', () => {
      it('excludes all filters that have fees, regardless of adjustedFee status', () => {
        const result = getChargesFiltersComboboxDataFromInvoiceSubscription({
          defaultFilterOptionLabel: 'Default filter',
          subscription: invoiceSubWithFiltersForOverride,
          selectedChargeId: 'charge-with-filters-override',
          overrideFees: overrideFeesWithFilters,
        })

        // Both filters have fees, so neither should appear
        // Default filter should appear since there's no fee for it
        expect(result).toEqual([
          {
            label: 'Default filter',
            value: '__ALL_FILTER_VALUES__',
          },
        ])
      })

      it('allows all filters when overrideFees is empty array', () => {
        const result = getChargesFiltersComboboxDataFromInvoiceSubscription({
          defaultFilterOptionLabel: 'Default filter',
          subscription: invoiceSubWithFiltersForOverride,
          selectedChargeId: 'charge-with-filters-override',
          overrideFees: [],
        })

        // With empty overrideFees, all filters should be available
        expect(result).toEqual([
          {
            label: 'Default filter',
            value: '__ALL_FILTER_VALUES__',
          },
          {
            label: 'payment_type • us',
            value: 'filter-1-override',
          },
          {
            label: 'payment_type • eu',
            value: 'filter-2-override',
          },
        ])
      })
    })
  })
})
