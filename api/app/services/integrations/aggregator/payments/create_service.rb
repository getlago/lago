# frozen_string_literal: true

module Integrations
  module Aggregator
    module Payments
      class CreateService < Integrations::Aggregator::Invoices::BaseService
        def initialize(payment:)
          @payment = payment

          super(invoice:)
        end

        def action_path
          "v1/#{provider}/payments"
        end

        def call
          return result unless integration
          return result unless integration.sync_payments
          return result unless invoice.finalized?
          return result if payload.integration_payment

          throttle!(:netsuite, :xero)

          response = http_client.post_with_response(payload.body, headers)
          body = JSON.parse(response.body)

          if body.is_a?(Hash)
            process_hash_result(body)
          else
            process_string_result(body)
          end

          return result unless result.external_id

          IntegrationResource.create!(
            organization_id: integration.organization_id,
            integration:,
            external_id: result.external_id,
            syncable_id: payment.id,
            syncable_type: "Payment",
            resource_type: :payment
          )

          result
        rescue LagoHttpClient::HttpError => e
          raise RequestLimitError(e) if request_limit_error?(e)

          code = code(e)
          message = message(e)

          deliver_error_webhook(customer:, code:, message:)

          return result unless [500, 424].include?(e.error_code.to_i)

          raise e
        end

        def call_async
          return result.not_found_failure!(resource: "payment") unless payment

          ::Integrations::Aggregator::Payments::CreateJob.perform_later(payment:)

          result.payment_id = payment.id
          result
        end

        private

        attr_reader :payment

        delegate :customer, to: :payment, allow_nil: true

        def invoice
          payment&.payable
        end

        def payload
          Integrations::Aggregator::Payments::Payloads::Factory.new_instance(integration:, payment:)
        end

        def process_hash_result(body)
          external_id = body["succeededPayment"]&.first.try(:[], "id")

          if external_id
            result.external_id = external_id
          else
            message = body["failedPayments"].first["validation_errors"].map { |error| error["Message"] }.join(". ")
            code = "Validation error"

            deliver_error_webhook(customer:, code:, message:)
          end
        end

        def process_string_result(body)
          result.external_id = body
        end
      end
    end
  end
end
