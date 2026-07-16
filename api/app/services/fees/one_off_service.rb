# frozen_string_literal: true

module Fees
  class OneOffService < BaseService
    Result = BaseResult[:fees]

    def initialize(invoice:, fees:)
      @invoice = invoice
      @fees = fees

      super(nil)
    end

    def call
      fees_result = []

      ActiveRecord::Base.transaction do
        fees.each do |fee|
          add_on = add_on(identifier: fee[add_on_identifier])

          result.not_found_failure!(resource: "add_on").raise_if_error! unless add_on
          result.single_validation_failure!(field: :boundaries, error_code: "values_are_invalid").raise_if_error! unless valid_boundaries?(fee)

          unit_amount_cents = fee[:unit_amount_cents] || add_on.amount_cents
          units = fee[:units]&.to_f || 1
          tax_codes = fee[:tax_codes]

          fee = Fee.new(
            invoice:,
            organization_id: invoice.organization_id,
            billing_entity_id: invoice.billing_entity_id,
            add_on:,
            invoice_display_name: fee[:invoice_display_name].presence,
            description: fee[:description] || add_on.description,
            unit_amount_cents:,
            amount_cents: (unit_amount_cents * units).round,
            precise_amount_cents: unit_amount_cents * units.to_d,
            amount_currency: invoice.currency,
            fee_type: :add_on,
            invoiceable_type: "AddOn",
            invoiceable: add_on,
            units:,
            payment_status: :pending,
            taxes_amount_cents: 0,
            taxes_precise_amount_cents: 0.to_d,
            properties: {
              from_datetime: from_datetime(fee),
              to_datetime: to_datetime(fee),
              timestamp: Time.current
            }
          )
          fee.precise_unit_amount = fee.unit_amount.to_f

          # Apply explicit payload taxes only when there is no tax provider.
          # Provider taxes take precedence and are handled async by ComputeTaxesAndTotalsService.
          # Explicit tax_codes must be applied here because they are ephemeral payload data.
          # Derived taxes (no tax_codes, no provider) are applied later by ComputeAmountsFromFees.
          if tax_codes.present? && !customer_provider_taxation?
            taxes_result = Fees::ApplyTaxesService.call(fee:, tax_codes:)
            taxes_result.raise_if_error!
          end

          fee.save!

          fees_result << fee
        end
      end

      result.fees = fees_result
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_reader :invoice, :fees

    delegate :customer, :organization, to: :invoice

    def add_on(identifier:)
      finder = api_context? ? :code : :id

      invoice.organization.add_ons.find_by(finder => identifier)
    end

    def add_on_identifier
      api_context? ? :add_on_code : :add_on_id
    end

    def customer_provider_taxation?
      return @customer_provider_taxation if defined?(@customer_provider_taxation)

      @customer_provider_taxation = customer.tax_customer.present?
    end

    def valid_boundaries?(fee)
      return true if fee[:from_datetime].nil? && fee[:to_datetime].nil?

      return false unless fee[:from_datetime] && fee[:to_datetime]
      return false unless Utils::Datetime.valid_format?(fee[:from_datetime])
      return false unless Utils::Datetime.valid_format?(fee[:to_datetime])

      from_datetime(fee) <= to_datetime(fee)
    end

    def from_datetime(fee)
      return Time.current if fee[:from_datetime].nil?

      Utils::Datetime.parse_iso8601(fee[:from_datetime])
    end

    def to_datetime(fee)
      return Time.current if fee[:to_datetime].nil?

      Utils::Datetime.parse_iso8601(fee[:to_datetime])
    end
  end
end
