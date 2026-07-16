# frozen_string_literal: true

module Queries
  class PaymentReceiptsQueryFiltersContract < Dry::Validation::Contract
    params do
      optional(:invoice_id).maybe(:string, format?: Regex::UUID)
    end
  end
end
