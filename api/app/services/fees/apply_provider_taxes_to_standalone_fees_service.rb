# frozen_string_literal: true

module Fees
  class ApplyProviderTaxesToStandaloneFeesService < BaseService
    Result = BaseResult

    def initialize(customer:, fees:, currency:)
      @customer = customer
      @fees = fees
      @currency = currency

      super
    end

    def call
      taxes_result = Integrations::Aggregator::Taxes::Invoices::CreateService.call(
        invoice: fake_invoice, fees:
      )
      return result unless taxes_result.success?

      fees.each do |fee|
        item_id = fee.id || fee.item_id
        fee_taxes = taxes_result.fees.find { |item| item.item_id == item_id }

        Fees::ApplyProviderTaxesService.call!(fee:, fee_taxes:)
      end

      result
    end

    private

    attr_reader :customer, :fees, :currency

    FakeInvoice = Data.define(:id, :issuing_date, :currency, :customer, :billing_entity)

    def fake_invoice
      FakeInvoice.new(
        id: SecureRandom.uuid,
        issuing_date: Time.current.in_time_zone(customer.applicable_timezone).to_date,
        currency:,
        customer:,
        billing_entity: customer.billing_entity
      )
    end
  end
end
