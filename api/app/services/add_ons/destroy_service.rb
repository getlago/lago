# frozen_string_literal: true

module AddOns
  class DestroyService < BaseService
    Result = BaseResult[:add_on]

    def initialize(add_on:)
      @add_on = add_on
      super
    end

    def call
      return result.not_found_failure!(resource: "add_on") unless add_on

      ActiveRecord::Base.transaction do
        add_on.discard!
        add_on.fixed_charges.update_all(deleted_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
      end

      result.add_on = add_on
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_reader :add_on
  end
end
