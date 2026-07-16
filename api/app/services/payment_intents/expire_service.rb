# frozen_string_literal: true

module PaymentIntents
  class ExpireService < BaseService
    Result = BaseResult[:payment_intents]

    def initialize(invoice:)
      @invoice = invoice
      super
    end

    def call
      payment_intents = PaymentIntent.active.where(invoice:)

      payment_intents.find_each do |payment_intent|
        if payment_intent.provider_session_id.present?
          Invoices::Payments::PaymentProviders::Factory
            .new_instance(invoice:)
            .expire_payment_url(payment_intent)
            .raise_if_error!
        end

        payment_intent.expired!
      end

      result.payment_intents = payment_intents
      result
    end

    private

    attr_reader :invoice
  end
end
