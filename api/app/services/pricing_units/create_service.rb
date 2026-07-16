# frozen_string_literal: true

module PricingUnits
  class CreateService < BaseService
    Result = BaseResult[:pricing_unit]

    def initialize(params)
      @params = params
      super
    end

    def call
      return result.forbidden_failure! unless License.premium?

      pricing_unit = PricingUnit.create!(
        params.slice(:organization, :name, :code, :short_name, :description)
      )

      result.pricing_unit = pricing_unit
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :params
  end
end
