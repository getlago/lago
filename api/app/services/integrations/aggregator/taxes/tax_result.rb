# frozen_string_literal: true

module Integrations
  module Aggregator
    module Taxes
      TaxResult = Data.define(
        :item_key,
        :item_id,
        :item_code,
        :amount_cents,
        :tax_amount_cents,
        :tax_breakdown
      )

      TaxResult::TaxBreakdownItem = Data.define(
        :name,
        :rate,
        :tax_amount,
        :type
      )
    end
  end
end
