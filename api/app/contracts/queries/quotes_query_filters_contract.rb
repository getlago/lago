# frozen_string_literal: true

module Queries
  class QuotesQueryFiltersContract < Dry::Validation::Contract
    params do
      optional(:customers).maybe do
        array(:string, format?: Regex::UUID)
      end
      optional(:external_customer_ids).maybe do
        array(:string)
      end
      optional(:statuses).maybe do
        array(:string, included_in?: QuoteVersion::STATUSES.values)
      end
      optional(:numbers).maybe do
        array(:string, format?: Quote::QUOTE_NUMBER_REGEX)
      end
      optional(:from_date).maybe(:date)
      optional(:to_date).maybe(:date)
      optional(:owners).maybe do
        array(:string, format?: Regex::UUID)
      end
      optional(:order_types).maybe do
        array(:string, included_in?: Quote::ORDER_TYPES.values)
      end
    end
  end
end
