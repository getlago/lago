# frozen_string_literal: true

module Integrations
  module Aggregator
    module Taxes
      module CreditNotes
        class CreateService < Integrations::Aggregator::Taxes::BaseService
          def initialize(credit_note:)
            @credit_note = credit_note

            super()
          end

          def action_path
            "v1/#{provider}/finalized_invoices"
          end

          def call
            return result unless integration
            return result unless ::Integrations::BaseIntegration::INTEGRATION_TAX_TYPES.include?(integration.type)

            response = http_client.post_with_response(payload, headers)
            body = JSON.parse(response.body)

            process_response(body)
            assign_external_customer_id
            create_integration_resource if result.succeeded_id

            result
          rescue LagoHttpClient::HttpError => e
            code = code(e)
            message = message(e)

            result.service_failure!(code:, message:)
          end

          private

          attr_reader :credit_note

          delegate :customer, to: :credit_note, allow_nil: true

          def payload
            Integrations::Aggregator::Taxes::CreditNotes::Payloads::Factory.new_instance(
              integration:,
              customer:,
              integration_customer:,
              credit_note:
            ).body
          end

          def create_integration_resource
            IntegrationResource.create!(
              organization_id: integration.organization_id,
              syncable_id: credit_note.id,
              syncable_type: "CreditNote",
              external_id: result.succeeded_id,
              integration_id: integration.id,
              resource_type: "credit_note"
            )
          end
        end
      end
    end
  end
end
