# frozen_string_literal: true

module Queries
  class InvoicesQueryFiltersContract < Dry::Validation::Contract
    params do
      optional(:billing_entity_ids).maybe { array(:string, format?: Regex::UUID) }

      optional(:settlements).maybe do
        value(:string, included_in?: InvoiceSettlement.settlement_types.keys) |
          array(:string, included_in?: InvoiceSettlement.settlement_types.keys)
      end

      optional(:payment_status).maybe do
        value(:string, included_in?: Invoice.payment_statuses.keys) |
          array(:string, included_in?: Invoice.payment_statuses.keys)
      end

      optional(:status).maybe do
        value(:string, included_in?: Invoice::VISIBLE_STATUS.keys.map(&:to_s)) |
          array(:string, included_in?: Invoice::VISIBLE_STATUS.keys.map(&:to_s))
      end

      optional(:self_billed).maybe(:bool)
      optional(:partially_paid).maybe(:bool)
      optional(:payment_overdue).maybe(:bool)
    end
  end
end
