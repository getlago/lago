# frozen_string_literal: true

module Types
  module FixedCharges
    class PropertiesInput < Types::BaseInputObject
      graphql_name "FixedChargePropertiesInput"

      # NOTE: Standard and Package charge model
      argument :amount, String, required: false

      # NOTE: Graduated charge model
      argument :graduated_ranges, [Types::ChargeModels::GraduatedRangeInput], required: false

      # NOTE: Volume charge model
      argument :volume_ranges, [Types::ChargeModels::VolumeRangeInput], required: false
    end
  end
end
