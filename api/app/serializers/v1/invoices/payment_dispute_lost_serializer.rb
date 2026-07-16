# frozen_string_literal: true

module V1
  module Invoices
    class PaymentDisputeLostSerializer < ModelSerializer
      def serialize
        result = {invoice:}
        result[:provider_error] = options[:provider_error] if options[:provider_error].present?
        result
      end

      private

      def invoice
        ::V1::InvoiceSerializer.new(model, includes: %i[customer]).serialize
      end
    end
  end
end
