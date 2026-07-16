# frozen_string_literal: true

module Charges
  class DestroyChildrenService < BaseService
    Result = BaseResult[:charge]

    def initialize(charge)
      @charge = charge
      super
    end

    def call
      return result unless charge
      return result unless charge.discarded?

      ActiveRecord::Base.transaction do
        # skip touching to avoid deadlocks
        Plan.no_touching do
          charge.children.joins(plan: :subscriptions).where(subscriptions: {status: %w[active pending]}).distinct.find_each do |charge|
            Charges::DestroyService.call!(charge:)
          end
        end
      end

      result.charge = charge
      result
    end

    private

    attr_reader :charge
  end
end
