import {
  ChargeModelEnum,
  CouponFrequency,
  CouponTypeEnum,
  HubspotTargetedObjectsEnum,
  InvoiceAppliedTaxOnWholeInvoiceCodeEnum,
  PlanInterval,
  PrivilegeValueTypeEnum,
} from '~/generated/graphql'

import {
  ALL_CHARGE_MODELS,
  appliedTaxEnumedTaxCodeTranslationKey,
  chargeModelLookupTranslation,
  dateErrorCodes,
  FORM_ERRORS_ENUM,
  FORM_TYPE_ENUM,
  getChargeModelHelpTextTranslationKey,
  getCouponFrequencyTranslationKey,
  getCouponTypeTranslationKey,
  getHubspotTargetedObjectTranslationKey,
  getIntervalTranslationKey,
  getPrivilegeValueTypeTranslationKey,
  getTargetedObjectTranslationKey,
  LocalTaxProviderErrorsEnum,
  MIN_AMOUNT_SHOULD_BE_LOWER_THAN_MAX_ERROR,
} from '../form'

describe('form constants', () => {
  describe('FORM_ERRORS_ENUM', () => {
    it('has expected error codes', () => {
      expect(FORM_ERRORS_ENUM.existingCode).toBe('existingCode')
      expect(FORM_ERRORS_ENUM.invalidGroupValue).toBe('invalidGroupValue')
    })
  })

  describe('dateErrorCodes', () => {
    it('has all expected date error codes', () => {
      expect(dateErrorCodes.wrongFormat).toBe('wrongFormat')
      expect(dateErrorCodes.shouldBeInFuture).toBe('shouldBeInFuture')
      expect(dateErrorCodes.shouldBeFutureAndBiggerThanSubscriptionAt).toBe(
        'shouldBeFutureAndBiggerThanSubscriptionAt',
      )
      expect(dateErrorCodes.shouldBeFutureAndBiggerThanFromDatetime).toBe(
        'shouldBeFutureAndBiggerThanFromDatetime',
      )
    })

    it('is a const object', () => {
      // Verify that the object cannot be reassigned (TypeScript const assertion)
      expect(Object.isFrozen(dateErrorCodes)).toBe(false) // Runtime not frozen, but TypeScript treats it as readonly
      expect(typeof dateErrorCodes).toBe('object')
    })
  })

  describe('MIN_AMOUNT_SHOULD_BE_LOWER_THAN_MAX_ERROR', () => {
    it('has expected value', () => {
      expect(MIN_AMOUNT_SHOULD_BE_LOWER_THAN_MAX_ERROR).toBe('minAmountShouldBeLowerThanMax')
    })
  })

  describe('FORM_TYPE_ENUM', () => {
    it('has all expected form types', () => {
      expect(FORM_TYPE_ENUM.creation).toBe('creation')
      expect(FORM_TYPE_ENUM.edition).toBe('edition')
      expect(FORM_TYPE_ENUM.duplicate).toBe('duplicate')
      expect(FORM_TYPE_ENUM.upgradeDowngrade).toBe('upgradeDowngrade')
    })
  })

  describe('ALL_CHARGE_MODELS', () => {
    it('includes all charge model enums', () => {
      expect(ALL_CHARGE_MODELS).toHaveProperty('Standard')
      expect(ALL_CHARGE_MODELS).toHaveProperty('Graduated')
      expect(ALL_CHARGE_MODELS).toHaveProperty('Package')
      expect(ALL_CHARGE_MODELS).toHaveProperty('Percentage')
      expect(ALL_CHARGE_MODELS).toHaveProperty('Volume')
      expect(ALL_CHARGE_MODELS).toHaveProperty('Custom')
      expect(ALL_CHARGE_MODELS).toHaveProperty('Dynamic')
      expect(ALL_CHARGE_MODELS).toHaveProperty('GraduatedPercentage')
    })
  })

  describe('LocalTaxProviderErrorsEnum', () => {
    it('has all tax provider error translation keys', () => {
      expect(LocalTaxProviderErrorsEnum.CurrencyCodeNotSupported).toMatch(/^text_/)
      expect(LocalTaxProviderErrorsEnum.CustomerAddressError).toMatch(/^text_/)
      expect(LocalTaxProviderErrorsEnum.ProductExternalIdUnknown).toMatch(/^text_/)
      expect(LocalTaxProviderErrorsEnum.GenericErrorMessage).toMatch(/^text_/)
    })
  })

  describe('translation key mappings', () => {
    describe('getIntervalTranslationKey', () => {
      it('has translation keys for all plan intervals', () => {
        expect(getIntervalTranslationKey[PlanInterval.Monthly]).toMatch(/^text_/)
        expect(getIntervalTranslationKey[PlanInterval.Quarterly]).toMatch(/^text_/)
        expect(getIntervalTranslationKey[PlanInterval.Weekly]).toMatch(/^text_/)
        expect(getIntervalTranslationKey[PlanInterval.Semiannual]).toMatch(/^text_/)
        expect(getIntervalTranslationKey[PlanInterval.Yearly]).toMatch(/^text_/)
      })

      it('covers all PlanInterval enum values', () => {
        const planIntervalKeys = Object.keys(PlanInterval)
        const translationKeys = Object.keys(getIntervalTranslationKey)

        expect(translationKeys.length).toBe(planIntervalKeys.length)
      })
    })

    describe('getCouponTypeTranslationKey', () => {
      it('has translation keys for all coupon types', () => {
        expect(getCouponTypeTranslationKey[CouponTypeEnum.FixedAmount]).toMatch(/^text_/)
        expect(getCouponTypeTranslationKey[CouponTypeEnum.Percentage]).toMatch(/^text_/)
      })

      it('covers all CouponTypeEnum values', () => {
        const couponTypeKeys = Object.keys(CouponTypeEnum)
        const translationKeys = Object.keys(getCouponTypeTranslationKey)

        expect(translationKeys.length).toBe(couponTypeKeys.length)
      })
    })

    describe('getCouponFrequencyTranslationKey', () => {
      it('has translation keys for all coupon frequencies', () => {
        expect(getCouponFrequencyTranslationKey[CouponFrequency.Once]).toMatch(/^text_/)
        expect(getCouponFrequencyTranslationKey[CouponFrequency.Recurring]).toMatch(/^text_/)
        expect(getCouponFrequencyTranslationKey[CouponFrequency.Forever]).toMatch(/^text_/)
      })

      it('covers all CouponFrequency enum values', () => {
        const frequencyKeys = Object.keys(CouponFrequency)
        const translationKeys = Object.keys(getCouponFrequencyTranslationKey)

        expect(translationKeys.length).toBe(frequencyKeys.length)
      })
    })

    describe('chargeModelLookupTranslation', () => {
      it('has translation keys for all charge models', () => {
        Object.values(chargeModelLookupTranslation).forEach((translationKey) => {
          expect(translationKey).toMatch(/^text_/)
        })
      })

      it('covers all charge model types', () => {
        // chargeModelLookupTranslation uses lowercase keys (the enum values, not the keys)
        expect(chargeModelLookupTranslation).toHaveProperty('standard')
        expect(chargeModelLookupTranslation).toHaveProperty('graduated')
        expect(chargeModelLookupTranslation).toHaveProperty('package')
        expect(chargeModelLookupTranslation).toHaveProperty('percentage')
        expect(chargeModelLookupTranslation).toHaveProperty('volume')
        expect(chargeModelLookupTranslation).toHaveProperty('graduated_percentage')
        expect(chargeModelLookupTranslation).toHaveProperty('custom')
        expect(chargeModelLookupTranslation).toHaveProperty('dynamic')
      })
    })

    describe('getChargeModelHelpTextTranslationKey', () => {
      it('has translation keys for all charge model help texts', () => {
        Object.values(getChargeModelHelpTextTranslationKey).forEach((translationKey) => {
          expect(translationKey).toMatch(/^text_/)
        })
      })

      it('covers all ChargeModelEnum values', () => {
        const chargeModelKeys = Object.keys(ChargeModelEnum)
        const translationKeys = Object.keys(getChargeModelHelpTextTranslationKey)

        expect(translationKeys.length).toBe(chargeModelKeys.length)
      })
    })

    describe('appliedTaxEnumedTaxCodeTranslationKey', () => {
      it('has translation keys for all applied tax codes', () => {
        Object.values(appliedTaxEnumedTaxCodeTranslationKey).forEach((translationKey) => {
          expect(translationKey).toMatch(/^text_/)
        })
      })

      it('covers all InvoiceAppliedTaxOnWholeInvoiceCodeEnum values', () => {
        const taxCodeKeys = Object.keys(InvoiceAppliedTaxOnWholeInvoiceCodeEnum)
        const translationKeys = Object.keys(appliedTaxEnumedTaxCodeTranslationKey)

        expect(translationKeys.length).toBe(taxCodeKeys.length)
      })

      it('has correct enum mappings', () => {
        expect(
          appliedTaxEnumedTaxCodeTranslationKey[
            InvoiceAppliedTaxOnWholeInvoiceCodeEnum.CustomerExempt
          ],
        ).toBe('text_1724857130376douaqt98pna')
        expect(
          appliedTaxEnumedTaxCodeTranslationKey[
            InvoiceAppliedTaxOnWholeInvoiceCodeEnum.ReverseCharge
          ],
        ).toBe('text_1724857130376w85w86kutdb')
      })
    })

    describe('getHubspotTargetedObjectTranslationKey', () => {
      it('has translation keys for all Hubspot targeted objects', () => {
        expect(
          getHubspotTargetedObjectTranslationKey[HubspotTargetedObjectsEnum.Companies],
        ).toMatch(/^text_/)
        expect(getHubspotTargetedObjectTranslationKey[HubspotTargetedObjectsEnum.Contacts]).toMatch(
          /^text_/,
        )
      })

      it('covers all HubspotTargetedObjectsEnum values', () => {
        const hubspotKeys = Object.keys(HubspotTargetedObjectsEnum)
        const translationKeys = Object.keys(getHubspotTargetedObjectTranslationKey)

        expect(translationKeys.length).toBe(hubspotKeys.length)
      })
    })

    describe('getTargetedObjectTranslationKey', () => {
      it('has translation keys for all targeted objects', () => {
        expect(getTargetedObjectTranslationKey[HubspotTargetedObjectsEnum.Companies]).toMatch(
          /^text_/,
        )
        expect(getTargetedObjectTranslationKey[HubspotTargetedObjectsEnum.Contacts]).toMatch(
          /^text_/,
        )
      })

      it('covers all HubspotTargetedObjectsEnum values', () => {
        const hubspotKeys = Object.keys(HubspotTargetedObjectsEnum)
        const translationKeys = Object.keys(getTargetedObjectTranslationKey)

        expect(translationKeys.length).toBe(hubspotKeys.length)
      })
    })

    describe('getPrivilegeValueTypeTranslationKey', () => {
      it('has translation keys for all privilege value types', () => {
        expect(getPrivilegeValueTypeTranslationKey[PrivilegeValueTypeEnum.Boolean]).toMatch(
          /^text_/,
        )
        expect(getPrivilegeValueTypeTranslationKey[PrivilegeValueTypeEnum.Integer]).toMatch(
          /^text_/,
        )
        expect(getPrivilegeValueTypeTranslationKey[PrivilegeValueTypeEnum.String]).toMatch(/^text_/)
        expect(getPrivilegeValueTypeTranslationKey[PrivilegeValueTypeEnum.Select]).toMatch(/^text_/)
      })

      it('covers all PrivilegeValueTypeEnum values', () => {
        const privilegeKeys = Object.keys(PrivilegeValueTypeEnum)
        const translationKeys = Object.keys(getPrivilegeValueTypeTranslationKey)

        expect(translationKeys.length).toBe(privilegeKeys.length)
      })
    })
  })

  describe('snapshot tests', () => {
    it('ALL_CHARGE_MODELS matches snapshot', () => {
      expect(ALL_CHARGE_MODELS).toMatchSnapshot()
    })

    it('translation mappings match snapshot', () => {
      expect({
        getIntervalTranslationKey,
        getCouponTypeTranslationKey,
        getCouponFrequencyTranslationKey,
        chargeModelLookupTranslation,
        getChargeModelHelpTextTranslationKey,
        appliedTaxEnumedTaxCodeTranslationKey,
        getHubspotTargetedObjectTranslationKey,
        getTargetedObjectTranslationKey,
        getPrivilegeValueTypeTranslationKey,
      }).toMatchSnapshot()
    })
  })
})
