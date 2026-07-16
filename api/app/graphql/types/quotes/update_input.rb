# frozen_string_literal: true

module Types
  module Quotes
    class UpdateInput < BaseInputObject
      graphql_name "UpdateQuoteInput"

      argument :id, ID, required: true
      argument :owners, [ID], required: false
    end
  end
end
