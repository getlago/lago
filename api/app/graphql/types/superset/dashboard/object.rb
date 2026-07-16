# frozen_string_literal: true

module Types
  module Superset
    module Dashboard
      class Object < Types::BaseObject
        graphql_name "SupersetDashboard"

        field :dashboard_title, String, null: false
        field :embedded_id, String, null: false
        field :guest_token, String, null: false
        field :id, String, null: false
        field :superset_url, String, null: false

        def superset_url
          ENV["SUPERSET_URL"]
        end
      end
    end
  end
end
