# frozen_string_literal: true

module PricingUnits
  class UpdateService < BaseService
    Result = BaseResult[:pricing_unit]

    def initialize(pricing_unit:, params:)
      @pricing_unit = pricing_unit
      @params = params
      super
    end

    def call
      return result.forbidden_failure! unless License.premium?
      return result.not_found_failure!(resource: "pricing_unit") unless pricing_unit

      pricing_unit.update!(
        params.slice(:name, :short_name, :description)
      )

      result.pricing_unit = pricing_unit
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :pricing_unit, :params
  end
end
