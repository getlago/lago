# frozen_string_literal: true

module PaymentMethods
  class FindOrCreateFromProviderService < BaseService
    Result = BaseResult[:payment_method]

    def initialize(customer:, payment_provider_customer:, provider_method_id:, params: {}, set_as_default: false)
      @customer = customer
      @payment_provider_customer = payment_provider_customer
      @provider_method_id = provider_method_id
      @params = params
      @set_as_default = set_as_default

      super
    end

    def call
      return result unless provider_method_id

      payment_method = find_payment_method || create_from_provider

      SetAsDefaultService.call(payment_method:) if set_as_default?

      result.payment_method = payment_method
      result
    rescue ActiveRecord::RecordNotUnique
      result.payment_method = find_payment_method
      result
    end

    private

    attr_reader :customer, :payment_provider_customer, :provider_method_id, :params, :set_as_default
    alias_method :set_as_default?, :set_as_default

    def find_payment_method
      PaymentMethod.find_by(
        customer:,
        payment_provider_customer:,
        provider_method_id:
      )
    end

    def create_from_provider
      CreateFromProviderService.call(
        customer:,
        params: {provider_payment_methods: params[:provider_payment_methods]},
        provider_method_id:,
        payment_provider_id: payment_provider_customer.payment_provider_id,
        payment_provider_customer:,
        details: params[:details]
      ).payment_method
    end
  end
end
