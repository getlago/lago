# frozen_string_literal: true

module AppliedPricingUnits
  class UpdateService < BaseService
    Result = BaseResult[:charge]

    def initialize(charge:, cascade_options:, params:)
      @charge = charge
      @cascade_options = cascade_options || {}
      @params = params || {}

      super
    end

    def call
      return result.not_found_failure!(resource: "charge") unless charge
      return result unless charge.applied_pricing_unit
      return result unless update_conversion_rate?

      charge.applied_pricing_unit.update!(conversion_rate: params[:conversion_rate])
      result.charge = charge

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    def update_conversion_rate?
      params.dig(:conversion_rate).present? &&
        (!cascade_options[:cascade] || cascade_options[:equal_applied_pricing_unit_rate])
    end

    private

    attr_reader :charge, :cascade_options, :params
  end
end
