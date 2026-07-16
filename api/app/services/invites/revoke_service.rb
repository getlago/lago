# frozen_string_literal: true

module Invites
  class RevokeService < BaseService
    Result = BaseResult[:invite]

    def initialize(invite)
      @invite = invite
      super
    end

    def call
      return result.not_found_failure!(resource: "invite") unless invite
      return result.not_found_failure!(resource: "invite") unless invite.pending?

      invite.mark_as_revoked!

      result.invite = invite
      result
    end

    private

    attr_reader :invite
  end
end
