# frozen_string_literal: true

module Types
  module Invites
    class UpdateInput < Types::BaseInputObject
      graphql_name "UpdateInviteInput"

      argument :id, ID, required: true
      argument :roles, [String], required: false
    end
  end
end
