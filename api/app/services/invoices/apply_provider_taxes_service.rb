# frozen_string_literal: true

module Invoices
  class ApplyProviderTaxesService < BaseService
    Result = BaseResult[:applied_taxes, :invoice]

    def initialize(invoice:, provider_taxes: nil)
      @invoice = invoice
      @provider_taxes = provider_taxes || fetch_provider_taxes_result.fees

      super
    end

    def call
      result.applied_taxes = []
      applied_taxes_amount_cents = 0
      taxes_rate = 0

      applicable_taxes.values.each do |tax|
        tax_rate = tax.rate.to_f * 100

        applied_tax = invoice.applied_taxes.new(
          organization: invoice.organization,
          tax_description: tax.type,
          tax_code: tax.name.parameterize(separator: "_"),
          tax_name: tax.name,
          tax_rate: tax_rate,
          amount_currency: invoice.currency
        )
        invoice.applied_taxes << applied_tax

        tax_amount_cents = compute_tax_amount_cents(tax)
        applied_tax.fees_amount_cents = fees_amount_cents(tax)
        applied_tax.taxable_base_amount_cents = taxable_base_amount_cents(tax)&.round
        applied_tax.amount_cents = tax_amount_cents.round

        # NOTE: when applied on user current usage, the invoice is
        #       not created in DB
        applied_tax.save! if invoice.persisted?

        applied_taxes_amount_cents += tax_amount_cents
        taxes_rate += pro_rated_taxes_rate(tax)

        result.applied_taxes << applied_tax
      end

      invoice.taxes_amount_cents = applied_taxes_amount_cents.round
      invoice.taxes_rate = taxes_rate.round(5)
      result.invoice = invoice

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :invoice, :provider_taxes

    def applicable_taxes
      return @applicable_taxes if defined? @applicable_taxes

      output = {}
      provider_taxes.each do |fee_taxes|
        fee_taxes.tax_breakdown.each do |tax|
          key = calculate_key(tax)

          next if output[key]

          output[key] = tax
        end
      end

      @applicable_taxes = output

      @applicable_taxes
    end

    def indexed_fees
      @indexed_fees ||= invoice.fees.each_with_object({}) do |fee, applied_taxes|
        fee.applied_taxes.each do |applied_tax|
          tax = OpenStruct.new(
            name: applied_tax.tax_name,
            rate: applied_tax.tax_rate,
            type: applied_tax.tax_description
          )
          key = calculate_key(tax)

          applied_taxes[key] ||= []
          applied_taxes[key] << fee
        end
      end
    end

    def compute_tax_amount_cents(tax)
      key = calculate_key(tax)

      indexed_fees[key]
        .sum { |fee| fee.sub_total_excluding_taxes_amount_cents * fee.taxes_base_rate * tax.rate.to_f }
    end

    def pro_rated_taxes_rate(tax)
      tax_rate = tax.rate.is_a?(String) ? tax.rate.to_f * 100 : tax.rate

      fees_rate = if invoice.sub_total_excluding_taxes_amount_cents.positive?
        fees_amount_cents(tax).fdiv(invoice.sub_total_excluding_taxes_amount_cents)
      else
        # NOTE: when invoice have a 0 amount. The prorata is on the number of fees
        key = calculate_key(tax)
        indexed_fees[key].count.fdiv(invoice.fees.count)
      end

      fees_rate * tax_rate
    end

    def fees_amount_cents(tax)
      key = calculate_key(tax)

      indexed_fees[key].sum(&:sub_total_excluding_taxes_amount_cents)
    end

    def taxable_base_amount_cents(tax)
      key = calculate_key(tax)

      indexed_fees[key].sum { |fee| fee.sub_total_excluding_taxes_amount_cents * fee.taxes_base_rate }
    end

    def fetch_provider_taxes_result
      taxes_result = if invoice.draft? || invoice.advance_charges?
        Integrations::Aggregator::Taxes::Invoices::CreateDraftService.call(invoice:)
      else
        Integrations::Aggregator::Taxes::Invoices::CreateService.call(invoice:)
      end
      taxes_result.raise_if_error!
    end

    def calculate_key(tax)
      tax_rate = tax.rate.is_a?(String) ? tax.rate.to_f * 100 : tax.rate

      "#{tax.type}-#{tax.name.parameterize(separator: "_")}-#{tax_rate}"
    end
  end
end
