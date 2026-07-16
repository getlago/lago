# frozen_string_literal: true

module ChargeModels
  class BuildDefaultPropertiesService < ::BaseService
    def initialize(charge_model)
      @charge_model = charge_model
      super
    end

    def call
      case charge_model&.to_sym
      when :standard then default_standard_properties
      when :graduated then default_graduated_properties
      when :package then default_package_properties
      when :percentage then default_percentage_properties
      when :volume then default_volume_properties
      when :graduated_percentage then default_graduated_percentage_properties
      when :dynamic then default_dynamic_properties
      end
    end

    private

    attr_reader :charge_model

    def default_standard_properties
      {amount: "0"}
    end

    def default_graduated_properties
      {
        graduated_ranges: [
          {
            from_value: 0,
            to_value: nil,
            per_unit_amount: "0",
            flat_amount: "0"
          }
        ]
      }
    end

    def default_package_properties
      {
        package_size: 1,
        amount: "0",
        free_units: 0
      }
    end

    def default_percentage_properties
      {rate: "0"}
    end

    def default_volume_properties
      {
        volume_ranges: [
          {
            from_value: 0,
            to_value: nil,
            per_unit_amount: "0",
            flat_amount: "0"
          }
        ]
      }
    end

    def default_graduated_percentage_properties
      {
        graduated_percentage_ranges: [
          {
            from_value: 0,
            to_value: nil,
            rate: "0",
            fixed_amount: "0",
            flat_amount: "0"
          }
        ]
      }
    end

    def default_dynamic_properties
      {}
    end
  end
end
