# frozen_string_literal: true

require "lago_http_client"

module DataApi
  class BaseService < BaseService
    def initialize(organization, **params)
      @organization = organization
      @params = params

      super()
    end

    private

    attr_reader :organization, :params

    def http_client
      @http_client ||= LagoHttpClient::Client.new(endpoint_url, retry_on_transient_errors: true)
    end

    def headers
      {
        "Authorization" => "Bearer #{ENV["LAGO_DATA_API_BEARER_TOKEN"]}"
      }
    end

    def endpoint_url
      "#{ENV["LAGO_DATA_API_URL"]}/#{action_path}"
    end

    def action_path
      raise NotImplementedError
    end
  end
end
