# frozen_string_literal: true

module Integrations
  module Aggregator
    module Invoices
      class CreateService < BaseService
        INVALID_LOGIN_ATTEMPT = "INVALID_LOGIN_ATTEMPT"

        def initialize(invoice:, find_first: false)
          @find_first = find_first
          super(invoice:)
        end

        def action_path
          "v1/#{provider}/invoices"
        end

        def call
          return result unless integration
          return result unless integration.sync_invoices
          return result unless invoice.finalized?
          return result if payload.integration_invoice

          throttle!(:anrok, :netsuite, :xero)

          response = http_client.post_with_response(payload.body, headers)
          body = JSON.parse(response.body)

          if body.is_a?(Hash)
            process_hash_result(body)
          else
            process_string_result(body)
          end

          Rails.logger.info "Response body: #{body}"
          Rails.logger.info "External ID: #{result.external_id}"

          return result unless result.external_id

          Rails.logger.info "Creating integration resource with external ID: #{result.external_id}"

          IntegrationResource.create!(
            organization_id: integration.organization_id,
            integration:,
            external_id: result.external_id,
            syncable_id: invoice.id,
            syncable_type: "Invoice",
            resource_type: :invoice
          )

          Rails.logger.info "Integration resource created. external ID: #{result.external_id}, invoice ID: #{invoice.id}"

          result
        rescue LagoHttpClient::HttpError => e
          raise RequestLimitError(e) if request_limit_error?(e)

          code = code(e)
          message = message(e)

          deliver_error_webhook(customer:, code:, message:)

          raise e if retryable_error?(e)

          result.non_retryable_failure!(code:, message:)
        rescue Integrations::Aggregator::BasePayload::Failure => e
          deliver_error_webhook(customer:, code: e.code, message: e.code.humanize)
          result.non_retryable_failure!(code: e.code, message: e.code.humanize)
        end

        def call_async
          return result.not_found_failure!(resource: "invoice") unless invoice

          ::Integrations::Aggregator::Invoices::CreateJob.perform_later(invoice:, find_first:)

          result.invoice_id = invoice.id
          result
        end

        private

        attr_reader :find_first

        def process_hash_result(body)
          external_id = body["succeededInvoices"]&.first.try(:[], "id")

          if external_id
            result.external_id = external_id
          else
            message = body["failedInvoices"].first["validation_errors"].map { |error| error["Message"] }.join(". ")
            code = "Validation error"

            deliver_error_webhook(customer:, code:, message:)
          end
        end

        def process_string_result(body)
          result.external_id = body
        end

        def retryable_error?(http_error)
          server_error = http_error.error_code.to_i >= 500 || http_error.error_code.to_i == 424
          server_error && !invalid_login_attempt_error?(http_error)
        end

        def invalid_login_attempt_error?(http_error)
          http_error.error_body.include?(INVALID_LOGIN_ATTEMPT)
        end
      end
    end
  end
end
