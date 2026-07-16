# frozen_string_literal: true

module V1
  module Errors
    class StripeErrorSerializer < ErrorSerializer
      def serialize
        {
          code: error.code,
          message: error.message,
          request_id: error.request_id,
          http_status: error.http_status,
          http_body: JSON.parse(error.http_body || "{}")
        }
      end
    end
  end
end
