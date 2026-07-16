# frozen_string_literal: true

module Api
  module V1
    class WebhooksController < Api::BaseController
      # Deprecated method
      def public_key
        render(plain: Base64.encode64(RsaPublicKey.to_s))
      end

      def json_public_key
        render(
          json: {
            webhook: {
              public_key: Base64.encode64(RsaPublicKey.to_s)
            }
          },
          status: :ok
        )
      end

      private

      def resource_name
        "webhook_jwt_public_key"
      end
    end
  end
end
