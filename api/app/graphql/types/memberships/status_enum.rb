# frozen_string_literal: true

module Types
  module Memberships
    class StatusEnum < Types::BaseEnum
      graphql_name "MembershipStatus"

      Membership::STATUSES.each do |type|
        value type
      end
    end
  end
end
