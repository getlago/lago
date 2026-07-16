# frozen_string_literal: true

module DunningCampaigns
  class ProcessAttemptService < BaseService
    Result = BaseResult[:customer, :payment_request]

    def initialize(customer:, dunning_campaign_threshold:, billing_entity:)
      @customer = customer
      @dunning_campaign_threshold = dunning_campaign_threshold
      @dunning_campaign = dunning_campaign_threshold.dunning_campaign
      @organization = customer.organization
      @billing_entity = billing_entity

      super
    end

    def call
      return result unless organization.auto_dunning_enabled?
      return result unless applicable_dunning_campaign?
      return result unless dunning_campaign_threshold_reached?

      ActiveRecord::Base.transaction do
        payment_request_result = PaymentRequests::CreateService.call(
          organization:,
          params: {
            external_customer_id: customer.external_id,
            lago_invoice_ids: overdue_invoices.pluck(:id)
          },
          dunning_campaign:
        ).raise_if_error!

        result.customer = customer
        result.payment_request = payment_request_result.payment_request
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :customer, :dunning_campaign, :dunning_campaign_threshold, :organization, :billing_entity

    def applicable_dunning_campaign?
      return false if customer.exclude_from_dunning_campaign?

      custom_campaign = customer.applied_dunning_campaign
      # Dunning campaign is resolved at the customer level (from their own billing entity), not from the invoice's BE.
      default_campaign = customer.billing_entity.applied_dunning_campaign

      custom_campaign == dunning_campaign || (!custom_campaign && default_campaign == dunning_campaign)
    end

    def dunning_campaign_threshold_reached?
      overdue_invoices_in_currency.sum(:total_amount_cents) >= dunning_campaign_threshold.amount_cents
    end

    def overdue_invoices_in_currency
      @overdue_invoices_in_currency ||= customer
        .invoices
        .non_self_billed
        .payment_overdue
        .where(ready_for_payment_processing: true)
        .where(currency: dunning_campaign_threshold.currency)
    end

    def overdue_invoices
      overdue_invoices_in_currency.where(billing_entity_id: billing_entity.id)
    end
  end
end
