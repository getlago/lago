# frozen_string_literal: true

module Integrations
  module Aggregator
    module Invoices
      module Hubspot
        class CreateCustomerAssociationService < BaseService
          def action_path
            "v1/#{provider}/association"
          end

          def call
            return result if !integration || !integration.sync_invoices || !payload.integration_invoice

            Integrations::Hubspot::Invoices::DeployObjectService.call(integration:)

            throttle!(:hubspot)

            http_client.put_with_response(payload.customer_association_body, headers)

            result
          rescue LagoHttpClient::HttpError => e
            raise RequestLimitError(e) if request_limit_error?(e)

            code = code(e)
            message = message(e)

            deliver_error_webhook(customer:, code:, message:)

            raise e
          rescue Integrations::Aggregator::BasePayload::Failure => e
            deliver_error_webhook(customer:, code: e.code, message: e.code.humanize)
          end
        end
      end
    end
  end
end
