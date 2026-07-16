# frozen_string_literal: true

module Types
  module Auth
    module Google
      class AuthUrl < Types::BaseObject
        field :url, String, null: false
      end
    end
  end
end
