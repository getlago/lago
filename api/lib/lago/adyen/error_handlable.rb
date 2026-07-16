# frozen_string_literal: true

module Lago
  module Adyen
    module ErrorHandlable
      def handle_adyen_response(res)
        return [true, nil] if res.status < 400

        code = res.response["errorType"]
        message = res.response["message"]

        error = ::Adyen::AdyenError.new(nil, nil, message, code)
        deliver_error_webhook(error)

        [false, error]
      end
    end
  end
end
