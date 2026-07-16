# frozen_string_literal: true

module Integrations
  module Aggregator
    module Taxes
      module Invoices
        class CreateService < BaseService
          def action_path
            "v1/#{provider}/finalized_invoices"
          end

          def call
            return result unless integration
            return result unless ::Integrations::BaseIntegration::INTEGRATION_TAX_TYPES.include?(integration.type)

            throttle!(:anrok, :avalara)

            response = http_client.post_with_response(payload, headers)
            body = parse_response(response)

            process_response(body)
            assign_external_customer_id
            create_integration_resource if integration.type.to_s == "Integrations::AvalaraIntegration" && result.succeeded_id

            result
          rescue LagoHttpClient::HttpError => e
            raise Integrations::Aggregator::RequestLimitError(e) if request_limit_error?(e)
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
            payload_body = Integrations::Aggregator::Taxes::Invoices::Payloads::Factory.new_instance(
              integration:,
              invoice:,
              customer:,
              integration_customer:,
              fees:
            ).body

            invoice_data = payload_body.first
            invoice_data["id"] = invoice.id
            if integration.type.to_s == "Integrations::AvalaraIntegration"
              invoice_data["type"] = invoice.voided? ? "returnInvoice" : "salesInvoice"
            end

            [invoice_data]
          end

          def create_integration_resource
            IntegrationResource.create!(
              organization_id: integration.organization_id,
              syncable_id: invoice.id,
              syncable_type: "Invoice",
              external_id: result.succeeded_id,
              integration_id: integration.id,
              resource_type: :invoice
            )
          end
        end
      end
    end
  end
end
