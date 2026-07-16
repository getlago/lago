# frozen_string_literal: true

module FixedCharges
  class GenerateCodeService < BaseService
    Result = BaseResult[:code]

    def initialize(plan:, add_on:)
      @plan = plan
      @add_on = add_on

      super
    end

    def call
      result.code = generate_unique_code
      result
    end

    private

    attr_reader :plan, :add_on

    def generate_unique_code
      base_code = add_on.code

      return base_code unless plan.fixed_charges.parents.exists?(code: base_code)

      existing_suffixes = plan.fixed_charges.parents
        .where("code ~ ?", "^#{Regexp.escape(base_code)}_\\d+$")
        .pluck(:code)
        .map { |code| code.delete_prefix("#{base_code}_").to_i }

      next_suffix = (existing_suffixes.max || 1) + 1

      "#{base_code}_#{next_suffix}"
    end
  end
end
