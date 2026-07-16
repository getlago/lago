# frozen_string_literal: true

module Types
  module Fees
    module AppliedTaxes
      class Object < Types::BaseObject
        graphql_name "FeeAppliedTax"
        implements Types::Taxes::AppliedTax

        field :fee, Types::Fees::Object, null: false
      end
    end
  end
end
