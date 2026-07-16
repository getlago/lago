# frozen_string_literal: true

module Integrations
  module Aggregator
    module Contacts
      class BaseService < Integrations::Aggregator::BaseService
        def action_path
          "v1/#{provider}/contacts"
        end

        private

        def headers
          {
            "Connection-Id" => integration.connection_id,
            "Authorization" => "Bearer #{secret_key}",
            "Provider-Config-Key" => provider_key
          }
        end

        def deliver_success_webhook(customer:, webhook_code:)
          SendWebhookJob.perform_later(
            webhook_code,
            customer
          )
        end

        def process_hash_result(body)
          contact = body["succeededContacts"]&.first
          contact_id = contact&.dig("id")
          email = contact&.dig("email")

          if contact_id
            result.contact_id = contact_id
            result.email = email if email.present?
          else
            message = if body.key?("failedContacts")
              body["failedContacts"].first["validation_errors"].map { |error| error["Message"] }.join(". ")
            else
              body.dig("error", "payload", "message")
            end

            code = "Validation error"

            deliver_error_webhook(customer:, code:, message:)
          end
        end

        def process_string_result(body)
          result.contact_id = body
        end

        def webhook_code
          case provider
          when "hubspot"
            "customer.crm_provider_created"
          else
            "customer.accounting_provider_created"
          end
        end
      end
    end
  end
end
