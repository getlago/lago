# frozen_string_literal: true

module Types
  module Wallets
    class AppliesToInput < BaseInputObject
      argument :billable_metric_ids, [ID], required: false
      argument :fee_types, [Types::Fees::TypesEnum], required: false
    end
  end
end
