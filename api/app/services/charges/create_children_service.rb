# frozen_string_literal: true

module Charges
  class CreateChildrenService < BaseService
    Result = BaseResult[:charge]

    def initialize(child_ids:, charge:, payload:)
      @charge = charge
      @payload = payload.deep_symbolize_keys
      @child_ids = child_ids
      super
    end

    def call
      return result.not_found_failure!(resource: "charge") unless charge

      ActiveRecord::Base.transaction do
        # skip touching to avoid deadlocks
        Plan.no_touching do
          plan.children.where(id: child_ids).find_each do |child|
            create_params = if payload[:code].present?
              payload
            else
              payload.merge(code: charge.code)
            end
            Charges::CreateService.call!(plan: child, params: create_params.merge(parent_id: charge.id))
          end
        end
      end

      result.charge = charge
      result
    end

    private

    attr_reader :charge, :payload, :child_ids

    delegate :plan, to: :charge
  end
end
