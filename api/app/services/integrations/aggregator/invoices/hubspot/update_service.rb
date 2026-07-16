# frozen_string_literal: true

module Integrations
  module Aggregator
    module Invoices
      module Hubspot
        class UpdateService < BaseService
          def call
            return result unless integration
            return result unless integration.sync_invoices
            return result unless payload.integration_invoice

            Integrations::Hubspot::Invoices::DeployPropertiesService.call(integration:)

            throttle!(:hubspot)

            response = http_client.put_with_response(payload.update_body, headers)
            body = JSON.parse(response.body)

            result.external_id = body["id"]
            result
          rescue LagoHttpClient::HttpError => e
            raise RequestLimitError(e) if request_limit_error?(e)

            code = code(e)
            message = message(e)

            deliver_error_webhook(customer:, code:, message:)

            result
          end

          def call_async
            return result.not_found_failure!(resource: "invoice") unless invoice

            ::Integrations::Aggregator::Invoices::Hubspot::UpdateJob.perform_later(invoice:)

            result.invoice_id = invoice.id
            result
          end
        end
      end
    end
  end
end
