# frozen_string_literal: true

module Integrations
  module Okta
    class DestroyService < Integrations::DestroyService
      def call
        return result.not_found_failure!(resource: "integration") unless integration
        return result.not_allowed_failure!(code: "enabled_authentication_methods_required") unless can_destroy?

        ActiveRecord::Base.transaction do
          result = super

          if result.success?
            organization = result.integration.organization
            organization.disable_okta_authentication! if organization.okta_authentication_enabled?
          end

          result
        end
      end

      private

      def can_destroy?
        (integration.organization.authentication_methods - [Organizations::AuthenticationMethods::OKTA]).size >= 1
      end
    end
  end
end
