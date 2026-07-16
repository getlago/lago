# frozen_string_literal: true

module Types
  module Payloads
    class RegisterUserType < Types::BaseObject
      field :membership, Types::MembershipType, null: false
      field :organization, Types::Organizations::OrganizationType, null: false
      field :token, String, null: false
      field :user, Types::UserType, null: false
    end
  end
end
