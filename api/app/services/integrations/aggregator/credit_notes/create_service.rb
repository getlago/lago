# frozen_string_literal: true

module Integrations
  module Aggregator
    module CreditNotes
      class CreateService < Integrations::Aggregator::Invoices::BaseService
        def initialize(credit_note:)
          @credit_note = credit_note

          super(invoice:)
        end

        def action_path
          "v1/#{provider}/creditnotes"
        end

        def call
          return result unless integration
          return result unless integration.sync_credit_notes
          return result unless credit_note.finalized?
          return result if payload.integration_credit_note

          throttle!(:anrok, :netsuite, :xero)

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
            syncable_id: credit_note.id,
            syncable_type: "CreditNote",
            resource_type: :credit_note
          )

          result
        rescue LagoHttpClient::HttpError => e
          raise RequestLimitError(e) if request_limit_error?(e)

          code = code(e)
          message = message(e)

          deliver_error_webhook(customer:, code:, message:)

          return result unless [500, 424].include?(e.error_code.to_i)

          raise e
        rescue Integrations::Aggregator::BasePayload::Failure => e
          deliver_error_webhook(customer:, code: e.code, message: e.code.humanize)
          result
        end

        def call_async
          return result.not_found_failure!(resource: "credit_note") unless credit_note

          ::Integrations::Aggregator::CreditNotes::CreateJob.perform_later(credit_note:)

          result.credit_note_id = credit_note.id
          result
        end

        private

        attr_reader :credit_note

        delegate :customer, :invoice, to: :credit_note, allow_nil: true

        def payload
          Integrations::Aggregator::CreditNotes::Payloads::Factory.new_instance(
            integration_customer:,
            credit_note:
          )
        end

        def process_hash_result(body)
          external_id = body["succeededCreditNotes"]&.first.try(:[], "id")

          if external_id
            result.external_id = external_id
          else
            message = body["failedCreditNotes"].first["validation_errors"].map { |error| error["Message"] }.join(". ")
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
