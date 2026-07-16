# frozen_string_literal: true

module Fees
  class EstimatePayInAdvanceService < BaseService
    Result = BaseResult[:fees]

    def initialize(organization:, params:)
      @organization = organization
      # NOTE: validation is shared with event creation and is expecting a transaction_id
      @event_params = params.merge(transaction_id: SecureRandom.uuid)

      super
    end

    def call
      validation_result = Events::ValidateCreationService.call(organization:, event_params:, customer:, subscriptions:)
      unless validation_result.success?
        result.fail_with_error!(validation_result.error)
        return result
      end

      if charges.none?
        return result.single_validation_failure!(field: :code, error_code: "does_not_match_an_instant_charge")
      end

      fees = []

      ApplicationRecord.transaction do
        charges.each { |charge| fees += estimated_charge_fees(charge) }

        # NOTE: make sure the event and fees are not persisted in database
        raise ActiveRecord::Rollback
      end

      fees.each { |f| f.pay_in_advance_event_id = nil }

      apply_taxes(fees)

      result.fees = fees
      result
    rescue BaseService::FailedResult => e
      result.fail_with_error!(e)
    end

    private

    attr_reader :organization, :event_params

    def event
      return @event if @event

      @event = Events::Common.new(
        id: nil,
        organization_id: organization.id,
        code: event_params[:code],
        external_subscription_id: subscriptions.first&.external_id,
        properties: event_params[:properties] || {},
        transaction_id: SecureRandom.uuid,
        timestamp: Time.current,
        precise_total_amount_cents: event_params[:precise_total_amount_cents] || 0,
        persisted: false
      )

      expression_result = Events::CalculateExpressionService.call(organization:, event: @event)
      result.validation_failure!(errors: expression_result.error.message) unless expression_result.success?
      result.raise_if_error!

      @event
    end

    def customer
      return @customer if @customer

      @customer = if event_params[:external_subscription_id]
        organization.subscriptions.find_by(external_id: event_params[:external_subscription_id])&.customer
      else
        Customer.find_by(external_id: event_params[:external_customer_id], organization_id: organization.id)
      end
    end

    def subscriptions
      return @subscriptions if defined? @subscriptions

      timestamp = Time.current
      subscriptions = organization.subscriptions.where(external_id: event_params[:external_subscription_id])

      @subscriptions = subscriptions
        .where("date_trunc('second', started_at::timestamp) <= ?", timestamp)
        .where("terminated_at IS NULL OR date_trunc('second', terminated_at::timestamp) >= ?", timestamp)
        .order("terminated_at DESC NULLS FIRST, started_at DESC")
    end

    def charges
      @charges ||= subscriptions.first
        .plan
        .charges
        .pay_in_advance
        .joins(:billable_metric)
        .where(billable_metric: {code: event.code})
    end

    def estimated_charge_fees(charge)
      Fees::CreatePayInAdvanceService.call!(charge:, event:, estimate: true).fees
    end

    def apply_taxes(fees)
      if customer&.tax_customer.present?
        Fees::ApplyProviderTaxesToStandaloneFeesService.call!(
          customer:, fees:, currency: subscriptions.first.plan.amount_currency
        )
      else
        fees.each { |fee| Fees::ApplyTaxesService.call!(fee:) }
      end
    end
  end
end
