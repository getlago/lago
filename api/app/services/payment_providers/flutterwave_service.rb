# frozen_string_literal: true

module PaymentProviders
  class FlutterwaveService < BaseService
    def create_or_update(**args)
      payment_provider_result = PaymentProviders::FindService.call(
        organization_id: args[:organization].id,
        code: args[:code],
        id: args[:id],
        payment_provider_type: "flutterwave"
      )

      flutterwave_provider = if payment_provider_result.success?
        payment_provider_result.payment_provider
      else
        PaymentProviders::FlutterwaveProvider.new(
          organization_id: args[:organization].id,
          code: args[:code]
        )
      end

      old_code = flutterwave_provider.code

      flutterwave_provider.secret_key = args[:secret_key] if args.key?(:secret_key)
      flutterwave_provider.success_redirect_url = args[:success_redirect_url] if args.key?(:success_redirect_url)
      flutterwave_provider.code = args[:code] if args.key?(:code)
      flutterwave_provider.name = args[:name] if args.key?(:name)
      flutterwave_provider.save!
      if payment_provider_code_changed?(flutterwave_provider, old_code, args)
        flutterwave_provider.customers.update_all(payment_provider_code: args[:code]) # rubocop:disable Rails/SkipsModelValidations
      end

      result.flutterwave_provider = flutterwave_provider
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end
  end
end
