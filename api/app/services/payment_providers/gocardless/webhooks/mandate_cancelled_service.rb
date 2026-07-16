# frozen_string_literal: true

module PaymentProviders
  module Gocardless
    module Webhooks
      class MandateCancelledService < BaseService
        Result = BaseResult[:gocardless_customer, :payment_method]

        def initialize(payment_provider:, mandate_id:)
          @payment_provider = payment_provider
          @mandate_id = mandate_id

          super
        end

        def call
          payment_method = find_payment_method_by_mandate

          return result unless payment_method

          gocardless_customer = payment_method.payment_provider_customer
          result.gocardless_customer = gocardless_customer

          if gocardless_customer&.provider_mandate_id == mandate_id
            gocardless_customer.provider_mandate_id = nil
            gocardless_customer.save!
          end

          destroy_result = PaymentMethods::DestroyService.call(payment_method:)
          result.payment_method = destroy_result.payment_method

          result
        rescue ActiveRecord::RecordInvalid => e
          result.record_validation_failure!(record: e.record)
        end

        private

        attr_reader :payment_provider, :mandate_id

        def find_payment_method_by_mandate
          PaymentMethod
            .where(organization_id: payment_provider.organization_id, payment_provider:)
            .find_by(provider_method_id: mandate_id)
        end
      end
    end
  end
end
