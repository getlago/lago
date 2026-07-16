# frozen_string_literal: true

module Queries
  class OrderFormsQueryFiltersContract < Dry::Validation::Contract
    params do
      optional(:status).maybe do
        value(:string, included_in?: OrderForm::STATUSES.keys.map(&:to_s)) |
          array(:string, included_in?: OrderForm::STATUSES.keys.map(&:to_s))
      end
      optional(:customer_id).maybe { value(:string, format?: Regex::UUID) | array(:string, format?: Regex::UUID) }
      optional(:number).maybe { value(:string) | array(:string) }
      optional(:quote_number).maybe { value(:string) | array(:string) }
      optional(:owner_id).maybe { value(:string, format?: Regex::UUID) | array(:string, format?: Regex::UUID) }
      optional(:created_at_from).maybe(:time)
      optional(:created_at_to).maybe(:time)
      optional(:expires_at_from).maybe(:time)
      optional(:expires_at_to).maybe(:time)
    end
  end
end
