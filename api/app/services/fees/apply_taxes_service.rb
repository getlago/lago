# frozen_string_literal: true

module Fees
  class ApplyTaxesService < BaseService
    Result = BaseResult[:applied_taxes]

    def initialize(fee:, tax_codes: nil, customer: nil, plan: nil)
      @fee = fee
      @tax_codes = tax_codes
      @customer = customer || fee.invoice&.customer || fee.subscription.customer
      @plan = plan || fee.subscription&.plan

      super
    end

    def call
      result.applied_taxes = []
      return result if fee.applied_taxes.any?

      applied_taxes_amount_cents = 0
      applied_precise_taxes_amount_cents = 0.to_d
      applied_taxes_rate = 0

      applicable_taxes.each do |tax|
        applied_tax = Fee::AppliedTax.new(
          organization_id: fee.organization_id,
          fee:,
          tax:,
          tax_description: tax.description,
          tax_code: tax.code,
          tax_name: tax.name,
          tax_rate: tax.rate,
          amount_currency: fee.amount_currency
        )
        fee.applied_taxes << applied_tax

        tax_amount_cents = (fee.sub_total_excluding_taxes_amount_cents * tax.rate).fdiv(100)
        tax_precise_amount_cents = (fee.sub_total_excluding_taxes_precise_amount_cents * tax.rate).fdiv(100.to_d)

        applied_tax.amount_cents = tax_amount_cents.round
        applied_tax.precise_amount_cents = tax_precise_amount_cents
        applied_tax.save! if fee.persisted?

        applied_taxes_amount_cents += tax_amount_cents
        applied_precise_taxes_amount_cents += tax_precise_amount_cents
        applied_taxes_rate += tax.rate

        result.applied_taxes << applied_tax
      end

      fee.taxes_amount_cents = applied_taxes_amount_cents.round
      fee.taxes_precise_amount_cents = applied_precise_taxes_amount_cents
      fee.taxes_rate = applied_taxes_rate

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :fee, :tax_codes, :customer, :plan

    def applicable_taxes
      # organization.taxes - are all taxes created on the organization
      return customer.organization.taxes.where(code: tax_codes) if tax_codes
      return fee.add_on.taxes if fee.add_on? && fee.add_on.taxes.any?
      return fee.charge.taxes if fee.charge? && fee.charge.taxes.any?
      return fee.fixed_charge.taxes if fee.fixed_charge? && fee.fixed_charge.taxes.any?
      return fee.invoiceable.taxes if fee.commitment? && fee.invoiceable.taxes.any?
      if (fee.charge? || fee.subscription? || fee.commitment? || fee.fixed_charge?) && plan.taxes.any?
        return plan.taxes
      end
      return customer.taxes if customer.taxes.any?

      # billing_entity.taxes - are the default taxes applied on the billing entity
      Tax.joins(:billing_entities_taxes).where(billing_entities_taxes: {billing_entity_id: customer.billing_entity_id})
    end
  end
end
