# frozen_string_literal: true

module Types
  module Invites
    class StatusTypeEnum < Types::BaseEnum
      graphql_name "InviteStatusTypeEnum"

      Invite::INVITE_STATUS.each do |type|
        value type
      end
    end
  end
end
