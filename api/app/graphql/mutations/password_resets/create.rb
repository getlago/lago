# frozen_string_literal: true

module Mutations
  module PasswordResets
    class Create < BaseMutation
      graphql_name "CreatePasswordReset"
      description "Creates a new password reset"

      argument :email, String, required: true
      field :id, String, null: false

      def resolve(email:)
        user = User.find_by(email:)
        result = ::PasswordResets::CreateService.call(user:)

        result.success? ? result : result_error(result)
      end
    end
  end
end
