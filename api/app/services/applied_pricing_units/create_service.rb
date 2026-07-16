# frozen_string_literal: true

module AppliedPricingUnits
  class CreateService < BaseService
    Result = BaseResult[:charge]

    def initialize(charge:, params:)
      @charge = charge
      @params = params || {}

      super
    end

    def call
      return result.not_found_failure!(resource: "charge") unless charge
      return result unless create_applied_pricing_unit?

      pricing_unit = charge.organization.pricing_units.find_by(code: params[:code])

      charge.create_applied_pricing_unit!(
        organization: charge.organization,
        pricing_unit:,
        conversion_rate: params[:conversion_rate]
      )

      result.charge = charge
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    def create_applied_pricing_unit?
      params.present? && License.premium?
    end

    private

    attr_reader :charge, :params
  end
end
