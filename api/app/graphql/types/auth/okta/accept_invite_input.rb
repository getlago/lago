# frozen_string_literal: true

module Types
  module Auth
    module Okta
      class AcceptInviteInput < BaseInputObject
        description "Accept Invite with Okta Oauth input arguments"

        argument :code, String, required: true
        argument :invite_token, String, required: true
        argument :state, String, required: true
      end
    end
  end
end
