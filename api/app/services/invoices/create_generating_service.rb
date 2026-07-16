# frozen_string_literal: true

module Invoices
  class CreateGeneratingService < BaseService
    Result = BaseResult[:invoice]

    def initialize(customer:, invoice_type:, datetime:, currency:, charge_in_advance: false, skip_charges: false, invoice_id: nil, invoicing_reason: nil, subscription_gated: false, billing_entity: nil) # rubocop:disable Metrics/ParameterLists
      @customer = customer
      @invoice_type = invoice_type
      @currency = currency
      @datetime = datetime
      @charge_in_advance = charge_in_advance
      @skip_charges = skip_charges
      @invoice_id = invoice_id
      @recurring = invoicing_reason&.to_sym == :subscription_periodic
      @subscription_gated = subscription_gated
      @billing_entity = billing_entity

      super
    end

    def call
      return result.forbidden_failure! if customer.partner_account? && !organization.revenue_share_enabled?

      ActiveRecord::Base.transaction do
        invoice = Invoice.create!(
          id: invoice_id || SecureRandom.uuid,
          organization:,
          billing_entity: billing_entity || customer.billing_entity,
          customer:,
          invoice_type:,
          currency:,
          timezone: customer.applicable_timezone,
          status: :generating,
          issuing_date:,
          expected_finalization_date:,
          payment_due_date:,
          net_payment_term: customer.applicable_net_payment_term,
          skip_charges:,
          self_billed: customer.partner_account?
        )
        result.invoice = invoice

        yield invoice if block_given?
      end

      result
    end

    private

    attr_accessor :customer, :invoice_type, :currency, :datetime, :charge_in_advance, :skip_charges, :invoice_id, :recurring, :subscription_gated, :billing_entity

    delegate :organization, to: :customer

    # NOTE: accounting date must be in customer timezone
    def issuing_date
      date = datetime.in_time_zone(customer.applicable_timezone).to_date
      return date if !grace_period? || charge_in_advance

      issuing_date_service = Invoices::IssuingDateService.new(customer_settings: customer, recurring:)
      date + issuing_date_service.issuing_date_adjustment.days
    end

    def expected_finalization_date
      date = datetime.in_time_zone(customer.applicable_timezone).to_date
      return date if !grace_period? || charge_in_advance

      date + customer.applicable_invoice_grace_period.days
    end

    def grace_period?
      return false if subscription_gated

      invoice_type.to_sym == :subscription
    end

    def payment_due_date
      (issuing_date + customer.applicable_net_payment_term.days).to_date
    end
  end
end
