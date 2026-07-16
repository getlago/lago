# frozen_string_literal: true

module Auth
  module Okta
    class LoginService < BaseService
      def initialize(code:, state:)
        @code = code
        @state = state

        super
      end

      def call
        check_state
        check_code
        check_okta_integration(result.email)

        query_okta_access_token
        check_userinfo(result.email)

        find_or_create_user
        find_or_create_membership

        unless result.user.active_organizations.pluck(:authentication_methods).flatten.uniq.include?(Organizations::AuthenticationMethods::OKTA)
          return result.single_validation_failure!(
            error_code: "login_method_not_authorized",
            field: Organizations::AuthenticationMethods::OKTA
          )
        end

        UserDevices::RegisterService.call!(user: result.user)
        generate_token
      rescue ValidationError => e
        result.single_validation_failure!(error_code: e.message)
        result
      end

      private

      attr_reader :code, :state

      def generate_token
        result.token = Auth::TokenService.encode(user: result.user, login_method: Organizations::AuthenticationMethods::OKTA)
        result
      rescue => e
        result.service_failure!(code: "token_encoding_error", message: e.message)
      end

      def find_or_create_user
        user = User.find_or_initialize_by(email: result.email)

        if user.new_record?
          user.password = SecureRandom.hex(16)
          user.save!
        end

        result.user = user
      end

      def find_or_create_membership
        result.user.memberships.find_or_create_by(organization_id: result.okta_integration.organization_id)
      end
    end
  end
end
