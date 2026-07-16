# frozen_string_literal: true

module FixedCharges
  class UpdateChildrenService < BaseService
    Result = BaseResult[:fixed_charge]

    def initialize(fixed_charge:, params:, old_parent_attrs:, child_ids:)
      @fixed_charge = fixed_charge
      @params = params
      @old_parent = FixedCharge.new(old_parent_attrs)
      @child_ids = child_ids

      super
    end

    def call
      return result unless fixed_charge

      ActiveRecord::Base.transaction do
        Plan.no_touching do
          fixed_charge.children.where(id: child_ids).find_each do |child_fixed_charge|
            FixedCharges::UpdateService.call!(
              fixed_charge: child_fixed_charge,
              params:,
              timestamp: Time.current.to_i,
              cascade_options: {
                cascade: true,
                equal_properties: old_parent.equal_properties?(child_fixed_charge)
              },
              trigger_billing: false
            )
          end
        end
      end

      result.fixed_charge = fixed_charge
      result
    end

    private

    attr_reader :fixed_charge, :params, :old_parent, :child_ids
  end
end
