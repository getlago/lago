# frozen_string_literal: true

module Types
  module Organizations
    class AuthenticationMethodsEnum < Types::BaseEnum
      description "Organization Authentication Methods Values"

      Organization::AUTHENTICATION_METHODS.each do |method|
        value method
      end
    end
  end
end
