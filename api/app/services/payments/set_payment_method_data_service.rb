# frozen_string_literal: true

module Payments
  class SetPaymentMethodDataService < BaseService
    Result = BaseResult[:payment]

    def initialize(payment:, provider_payment_method_id:)
      @payment = payment
      @payment_provider = payment.payment_provider
      @provider_payment_method_id = provider_payment_method_id

      super
    end

    def call
      if payment.provider_payment_method_id == provider_payment_method_id
        result.payment = payment
        return result
      end

      data = case payment_provider.type
      when PaymentProviders::StripeProvider.to_s
        retrieve_stripe_payment_method_data
      else
        raise NotImplementedError, "Service not implemented for #{payment_provider.payment_type}"
      end

      id = data.delete(:id)
      payment.update!(provider_payment_method_id: id, provider_payment_method_data: data)

      payment.payment_method&.update!(details: data)

      result.payment = payment
      result
    end

    private

    attr_reader :payment, :payment_provider, :provider_payment_method_id

    def retrieve_stripe_payment_method_data
      pm = ::Stripe::PaymentMethod.retrieve(provider_payment_method_id, {
        api_key: payment_provider.secret_key
      })

      data = {
        id: provider_payment_method_id,
        type: pm.type
      }

      if pm.respond_to?(:card) && pm.card
        data[:last4] = pm.card.last4
        data[:brand] = pm.card.display_brand
        data[:expiration_month] = pm.card.exp_month
        data[:expiration_year] = pm.card.exp_year
      end

      data
    end
  end
end
