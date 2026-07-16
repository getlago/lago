# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    include ApiErrors

    before_action :authenticate
    before_action :set_context_source

    private

    def authenticate
      auth_header = request.headers["Authorization"]

      if auth_header&.start_with?("Bearer ")
        begin
          token = auth_header.split(" ").second
          payload = Google::Auth::IDTokens.verify_oidc(
            token,
            aud: ENV["GOOGLE_AUTH_CLIENT_ID"]
          )

          CurrentContext.email = payload["email"]
          return true
        rescue Google::Auth::IDTokens::SignatureError
          return unauthorized_error
        end
      end

      # Fallback to X-Admin-API-Key header
      key_header = request.headers["X-Admin-API-Key"]
      expected_key = ENV["ADMIN_API_KEY"]

      if key_header.present? && expected_key.present? && ActiveSupport::SecurityUtils.secure_compare(key_header, expected_key)
        CurrentContext.email = nil
        return true
      end

      unauthorized_error
    end

    def set_context_source
      CurrentContext.source = "admin"
      CurrentContext.api_key_id = nil
    end
  end
end
