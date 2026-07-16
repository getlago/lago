# frozen_string_literal: true

module Integrations
  module Aggregator
    module Taxes
      module Invoices
        class NegateService < BaseService
          def action_path
            "v1/#{provider}/negate_invoices"
          end

          def call
            return result unless integration
            return result unless integration.type == "Integrations::AnrokIntegration"

            response = http_client.post_with_response(payload, headers)
            body = JSON.parse(response.body)

            process_void_response(body)

            result
          rescue LagoHttpClient::HttpError => e
            raise RequestLimitError(e) if request_limit_error?(e)
            raise Integrations::Aggregator::BadGatewayError.new(e.error_body, e.uri) if bad_gateway_error?(e)
            raise Integrations::Aggregator::TaskInProgressError if task_in_progress_error?(e)
            raise Integrations::Aggregator::TaskExpiredError if task_expired_error?(e)
            raise Integrations::Aggregator::OrchestratorFailureError if orchestrator_failure_error?(e)

            code = code(e)
            message = message(e)

            result.service_failure!(code:, message:)
          rescue Net::ReadTimeout, Net::OpenTimeout, OpenSSL::SSL::SSLError => e
            raise Integrations::Aggregator::TimeoutError, e.message
          end

          private

          def payload
            [
              {
                "id" => invoice.id,
                "voided_id" => "#{invoice.id}_voided"
              }
            ]
          end
        end
      end
    end
  end
end
