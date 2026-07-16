# frozen_string_literal: true

module PaymentProviders
  class CashfreeService < BaseService
    LINK_STATUS_ACTIONS = %w[PAID].freeze
    PAYMENT_ACTIONS = %w[SUCCESS FAILED USER_DROPPED CANCELLED VOID PENDING FLAGGED NOT_ATTEMPTED].freeze
    # REFUND_ACTIONS = %w[created funds_returned paid refund_settled failed].freeze

    def create_or_update(**args)
      payment_provider_result = PaymentProviders::FindService.call(
        organization_id: args[:organization].id,
        code: args[:code],
        id: args[:id],
        payment_provider_type: "cashfree"
      )

      cashfree_provider = if payment_provider_result.success?
        payment_provider_result.payment_provider
      else
        PaymentProviders::CashfreeProvider.new(
          organization_id: args[:organization].id,
          code: args[:code]
        )
      end

      old_code = cashfree_provider.code

      cashfree_provider.client_id = args[:client_id] if args.key?(:client_id)
      cashfree_provider.client_secret = args[:client_secret] if args.key?(:client_secret)
      cashfree_provider.success_redirect_url = args[:success_redirect_url] if args.key?(:success_redirect_url)
      cashfree_provider.code = args[:code] if args.key?(:code)
      cashfree_provider.name = args[:name] if args.key?(:name)
      cashfree_provider.save!

      if payment_provider_code_changed?(cashfree_provider, old_code, args)
        cashfree_provider.customers.update_all(payment_provider_code: args[:code]) # rubocop:disable Rails/SkipsModelValidations
      end

      result.cashfree_provider = cashfree_provider
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end
  end
end
