# frozen_string_literal: true

module FixedCharges
  class DestroyChildrenService < BaseService
    Result = BaseResult[:fixed_charge]

    def initialize(fixed_charge)
      @fixed_charge = fixed_charge
      super
    end

    def call
      return result unless fixed_charge
      return result unless fixed_charge.discarded?

      ActiveRecord::Base.transaction do
        # skip touching to avoid deadlocks
        Plan.no_touching do
          fixed_charge.children.joins(plan: :subscriptions).where(subscriptions: {status: %w[active pending]}).distinct.find_each do |child_fixed_charge|
            FixedCharges::DestroyService.call!(fixed_charge: child_fixed_charge)
          end
        end
      end

      result.fixed_charge = fixed_charge
      result
    end

    private

    attr_reader :fixed_charge
  end
end
