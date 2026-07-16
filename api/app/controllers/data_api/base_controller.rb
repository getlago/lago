# frozen_string_literal: true

module DataApi
  class BaseController < ApplicationController
    include ApiErrors

    before_action :authenticate
    before_action :set_context_source

    private

    def authenticate
      request.headers["Authorization"]

      key_header = request.headers["X-Data-API-Key"]
      expected_key = ENV["LAGO_DATA_API_BEARER_TOKEN"]

      if key_header.present? && expected_key.present? && ActiveSupport::SecurityUtils.secure_compare(key_header, expected_key)
        CurrentContext.email = nil
        return true
      end

      unauthorized_error
    end

    def set_context_source
      CurrentContext.source = "data"
      CurrentContext.api_key_id = nil
    end
  end
end
