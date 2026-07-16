# frozen_string_literal: true

module Types
  module DataApi
    class Metadata < Types::BaseObject
      graphql_name "DataApiMetadata"

      field :current_page, Integer, null: false
      field :next_page, Integer, null: false
      field :prev_page, Integer, null: false
      field :total_count, Integer, null: false
      field :total_pages, Integer, null: false
    end
  end
end
