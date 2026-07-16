# frozen_string_literal: true

module Integrations
  module Anrok
    class CreateService < Integrations::CreateService
      def call(**args)
        organization = Organization.find_by(id: args[:organization_id])

        return result.forbidden_failure! unless License.premium?

        integration = Integrations::AnrokIntegration.new(
          organization:,
          name: args[:name],
          code: args[:code],
          connection_id: args[:connection_id],
          api_key: args[:api_key]
        )

        integration.save!

        result.integration = integration
        result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      end
    end
  end
end
