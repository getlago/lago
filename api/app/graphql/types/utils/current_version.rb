# frozen_string_literal: true

module Types
  module Utils
    class CurrentVersion < Types::BaseObject
      field :github_url, String, null: false
      field :number, String, null: false
    end
  end
end
