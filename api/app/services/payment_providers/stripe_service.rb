# frozen_string_literal: true

module PaymentProviders
  class StripeService < BaseService
    # TODO: Split into 2 dedicated `PaymentProviders::Stripe::(Create|Update)Service`
    def create_or_update(**args)
      payment_provider_result = PaymentProviders::FindService.call(
        organization_id: args[:organization_id],
        code: args[:code],
        id: args[:id],
        payment_provider_type: "stripe"
      )

      stripe_provider = if payment_provider_result.success?
        payment_provider_result.payment_provider
      else
        PaymentProviders::StripeProvider.new(
          organization_id: args[:organization_id],
          code: args[:code]
        )
      end

      is_new = stripe_provider.new_record?
      old_code = stripe_provider.code

      stripe_provider.secret_key = args[:secret_key] if args.key?(:secret_key) && is_new
      stripe_provider.code = args[:code] if args.key?(:code)
      stripe_provider.name = args[:name] if args.key?(:name)
      stripe_provider.success_redirect_url = args[:success_redirect_url] if args.key?(:success_redirect_url)
      stripe_provider.supports_3ds = args[:supports_3ds] if args.key?(:supports_3ds)
      stripe_provider.save!

      if is_new
        PaymentProviders::Stripe::RegisterWebhookJob.perform_later(stripe_provider)
      end

      if payment_provider_code_changed?(stripe_provider, old_code, args)
        stripe_provider.customers.update_all(payment_provider_code: args[:code]) # rubocop:disable Rails/SkipsModelValidations
        # Until this job is processed, the webhook endpoint will return 400 error
        PaymentProviders::Stripe::RefreshWebhookJob.perform_later(stripe_provider)
      end

      result.stripe_provider = stripe_provider
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end
  end
end
