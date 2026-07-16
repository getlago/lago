# frozen_string_literal: true

module Integrations
  module Avalara
    class FetchCompanyIdJob < ApplicationJob
      queue_as "integrations"

      retry_on LagoHttpClient::HttpError, wait: :polynomially_longer, attempts: 3
      retry_on BaseService::ThrottlingError, wait: :polynomially_longer, attempts: 25

      def perform(integration:)
        Integrations::Avalara::FetchCompanyIdService.call!(integration:)
      end
    end
  end
end
