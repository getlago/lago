# frozen_string_literal: true

module PaymentProviders
  class AdyenService < BaseService
    def create_or_update(**args)
      payment_provider_result = PaymentProviders::FindService.call(
        organization_id: args[:organization].id,
        code: args[:code],
        id: args[:id],
        payment_provider_type: "adyen"
      )

      adyen_provider = if payment_provider_result.success?
        payment_provider_result.payment_provider
      else
        PaymentProviders::AdyenProvider.new(
          organization_id: args[:organization].id,
          code: args[:code]
        )
      end

      # api_key = adyen_provider.api_key
      old_code = adyen_provider.code

      adyen_provider.api_key = args[:api_key] if args.key?(:api_key)
      adyen_provider.code = args[:code] if args.key?(:code)
      adyen_provider.name = args[:name] if args.key?(:name)
      adyen_provider.merchant_account = args[:merchant_account] if args.key?(:merchant_account)
      adyen_provider.live_prefix = args[:live_prefix] if args.key?(:live_prefix)
      adyen_provider.hmac_key = args[:hmac_key] if args.key?(:hmac_key)
      adyen_provider.success_redirect_url = args[:success_redirect_url] if args.key?(:success_redirect_url)
      adyen_provider.save!

      if payment_provider_code_changed?(adyen_provider, old_code, args)
        adyen_provider.customers.update_all(payment_provider_code: args[:code]) # rubocop:disable Rails/SkipsModelValidations
      end

      result.adyen_provider = adyen_provider
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end
  end
end
