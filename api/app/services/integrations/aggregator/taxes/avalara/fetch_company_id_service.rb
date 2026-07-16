# frozen_string_literal: true

module Integrations
  module Aggregator
    module Taxes
      module Avalara
        class FetchCompanyIdService < Integrations::Aggregator::BaseService
          def action_path
            "v1/#{provider}/companies"
          end

          def call
            throttle!(:avalara)

            response = http_client.post_with_response(payload, headers)
            body = JSON.parse(response.body)

            received_company = body["companies"]&.first

            if received_company.blank?
              code = "company_not_found"
              message = "Company cannot be found in Avalara based on the provided code"

              deliver_integration_error_webhook(integration:, code:, message:)

              return result.service_failure!(code:, message:)
            end

            result.company = received_company

            result
          rescue LagoHttpClient::HttpError => e
            code = code(e)
            message = message(e)

            deliver_integration_error_webhook(integration:, code:, message:)

            result.service_failure!(code:, message:)
          end

          private

          def payload
            [
              {
                "company_code" => integration.company_code
              }
            ]
          end

          def headers
            {
              "Connection-Id" => integration.connection_id,
              "Authorization" => "Bearer #{secret_key}",
              "Provider-Config-Key" => provider_key
            }
          end
        end
      end
    end
  end
end
