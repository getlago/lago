# frozen_string_literal: true

module ChargeModels
  class FilterPropertiesService < ::BaseService
    Result = BaseResult[:properties]

    def initialize(chargeable:, properties:)
      @chargeable = chargeable
      @properties = properties&.with_indifferent_access || {}

      super
    end

    def call
      result.properties = filter_service_result.properties
      result
    end

    private

    attr_reader :chargeable, :properties

    def filter_service_result
      case chargeable
      when Charge
        ChargeModels::FilterProperties::ChargeService.call(chargeable:, properties:)
      when FixedCharge
        ChargeModels::FilterProperties::FixedChargeService.call(chargeable:, properties:)
      else
        raise ArgumentError, "Unsupported chargeable type: #{chargeable.class}"
      end
    end
  end
end
