# frozen_string_literal: true

module Invoices
  class IssuingDateService
    def initialize(customer_settings:, billing_entity_settings: nil, recurring: false)
      @customer_settings = customer_settings
      @billing_entity_settings = billing_entity_settings || customer_settings.try(:billing_entity) || {}
      @recurring = recurring
    end

    def issuing_date_adjustment
      return grace_period unless recurring

      send("#{anchor}_#{adjustment}")
    end

    def grace_period
      customer_settings[:invoice_grace_period] || billing_entity_settings[:invoice_grace_period] || 0
    end

    private

    attr_reader :customer_settings, :billing_entity_settings, :recurring

    def current_period_end_keep_anchor
      -1
    end

    def current_period_end_align_with_finalization_date
      # Fall back to the current period end date if the grace period is zero
      grace_period.zero? ? -1 : grace_period
    end

    def next_period_start_keep_anchor
      0
    end

    def next_period_start_align_with_finalization_date
      grace_period
    end

    def anchor
      customer_settings[:subscription_invoice_issuing_date_anchor] || billing_entity_settings[:subscription_invoice_issuing_date_anchor]
    end

    def adjustment
      customer_settings[:subscription_invoice_issuing_date_adjustment] || billing_entity_settings[:subscription_invoice_issuing_date_adjustment]
    end
  end
end
