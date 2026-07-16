# frozen_string_literal: true

module Queries
  class OrdersQueryFiltersContract < Dry::Validation::Contract
    params do
      optional(:status).maybe do
        value(:string, included_in?: Order::STATUSES.values) |
          array(:string, included_in?: Order::STATUSES.values)
      end
      optional(:order_type).maybe do
        value(:string, included_in?: Quote::ORDER_TYPES.values) |
          array(:string, included_in?: Quote::ORDER_TYPES.values)
      end
      optional(:execution_mode).maybe do
        value(:string, included_in?: Order::EXECUTION_MODES.values) |
          array(:string, included_in?: Order::EXECUTION_MODES.values)
      end
      optional(:customer_id).maybe { value(:string, format?: Regex::UUID) | array(:string, format?: Regex::UUID) }
      optional(:number).maybe { value(:string) | array(:string) }
      optional(:order_form_number).maybe { value(:string) | array(:string) }
      optional(:quote_number).maybe { value(:string) | array(:string) }
      optional(:owner_id).maybe { value(:string, format?: Regex::UUID) | array(:string, format?: Regex::UUID) }
      optional(:executed_at_from).maybe(:time)
      optional(:executed_at_to).maybe(:time)
    end
  end
end
