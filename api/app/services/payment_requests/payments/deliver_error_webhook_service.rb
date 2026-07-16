# frozen_string_literal: true

module PaymentRequests
  module Payments
    class DeliverErrorWebhookService < BaseService
      def initialize(payment_request, params)
        @payment_request = payment_request
        @params = params
      end

      def call_async
        SendWebhookJob.perform_later("payment_request.payment_failure", payment_request, params)

        result
      end

      private

      attr_reader :payment_request, :params
    end
  end
end
