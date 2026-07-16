# frozen_string_literal: true

module Integrations
  module Aggregator
    module Companies
      class BaseService < Integrations::Aggregator::Contacts::BaseService
        def action_path
          "v1/#{provider}/companies"
        end

        private

        def process_hash_result(body)
          contact = body["succeededCompanies"]&.first
          contact_id = contact&.dig("id")
          email = contact&.dig("email")

          if contact_id
            result.contact_id = contact_id
            result.email = email if email.present?
          else
            message = if body.key?("failedCompanies")
              body["failedCompanies"].first["validation_errors"].map { |error| error["Message"] }.join(". ")
            else
              body.dig("error", "payload", "message")
            end

            code = "Validation error"

            deliver_error_webhook(customer:, code:, message:)
          end
        end
      end
    end
  end
end
