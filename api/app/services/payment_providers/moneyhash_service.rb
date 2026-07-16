# frozen_string_literal: true

module PaymentProviders
  class MoneyhashService < BaseService
    def create_or_update(**args)
      payment_provider_result = PaymentProviders::FindService.call(
        organization_id: args[:organization].id,
        code: args[:code],
        id: args[:id],
        payment_provider_type: "moneyhash"
      )

      @moneyhash_provider = if payment_provider_result.success?
        payment_provider_result.payment_provider
      else
        PaymentProviders::MoneyhashProvider.new(
          organization_id: args[:organization].id,
          code: args[:code]
        )
      end

      old_code = moneyhash_provider.code
      moneyhash_provider.api_key = args[:api_key] if args.key?(:api_key)
      moneyhash_provider.code = args[:code] if args.key?(:code)
      moneyhash_provider.name = args[:name] if args.key?(:name)
      moneyhash_provider.flow_id = args[:flow_id] if args.key?(:flow_id)

      if moneyhash_provider.signature_key.blank?
        signature_result = get_signature_key
        return signature_result unless signature_result.success?
        moneyhash_provider.signature_key = signature_result.signature_key
      end

      moneyhash_provider.save(validate: false)

      if payment_provider_code_changed?(moneyhash_provider, old_code, args)
        moneyhash_provider.customers.update_all(payment_provider_code: args[:code]) # rubocop:disable Rails/SkipsModelValidations
      end

      result.moneyhash_provider = moneyhash_provider
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    attr_reader :moneyhash_provider

    private

    def get_signature_key
      response = LagoHttpClient::Client.new(
        "#{::PaymentProviders::MoneyhashProvider.api_base_url}/api/v1/organizations/get-webhook-signature-key/"
      ).get(
        headers: {
          "X-Api-Key" => moneyhash_provider.api_key
        }
      )
      result.signature_key = response["data"]["webhook_signature_secret"]
      result
    rescue LagoHttpClient::HttpError => e
      result.service_failure!(code: "moneyhash_error", message: "#{e.error_code}: #{e.error_body}")
    end
  end
end
