# frozen_string_literal: true

module Types
  module FixedCharges
    class Properties < Types::BaseObject
      graphql_name "FixedChargeProperties"

      # NOTE: Standard and Package charge model
      field :amount, String, null: true

      # NOTE: Graduated charge model
      field :graduated_ranges, [Types::ChargeModels::GraduatedRange], null: true

      # NOTE: Volume charge model
      field :volume_ranges, [Types::ChargeModels::VolumeRange], null: true
    end
  end
end
