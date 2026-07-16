# frozen_string_literal: true

module FixedCharges
  class CreateChildrenService < BaseService
    Result = BaseResult[:fixed_charge]

    def initialize(child_ids:, fixed_charge:, payload:)
      @fixed_charge = fixed_charge
      @payload = payload.deep_symbolize_keys
      @child_ids = child_ids
      super
    end

    def call
      return result.not_found_failure!(resource: "fixed_charge") unless fixed_charge

      ActiveRecord::Base.transaction do
        # skip touching to avoid deadlocks
        Plan.no_touching do
          plan.children.where(id: child_ids).find_each do |child|
            create_params = if payload[:code].present?
              payload
            else
              payload.merge(code: fixed_charge.code)
            end
            FixedCharges::CreateService.call!(plan: child, params: create_params.merge(parent_id: fixed_charge.id))
          end
        end
      end

      result.fixed_charge = fixed_charge
      result
    end

    private

    attr_reader :fixed_charge, :payload, :child_ids

    delegate :plan, to: :fixed_charge
  end
end
