# frozen_string_literal: true

module Types
  module Payloads
    class LoginUserType < Types::BaseObject
      field :token, String, null: false
      field :user, Types::UserType, null: false
    end
  end
end
