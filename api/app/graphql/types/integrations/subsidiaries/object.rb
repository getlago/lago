# frozen_string_literal: true

module Types
  module Integrations
    module Subsidiaries
      class Object < Types::BaseObject
        graphql_name "Subsidiary"

        field :external_id, String, null: false
        field :external_name, String, null: true
      end
    end
  end
end
