# frozen_string_literal: true

module Charges
  class GenerateCodeService < BaseService
    Result = BaseResult[:code]

    def initialize(plan:, billable_metric:)
      @plan = plan
      @billable_metric = billable_metric

      super
    end

    def call
      result.code = generate_unique_code
      result
    end

    private

    attr_reader :plan, :billable_metric

    def generate_unique_code
      base_code = billable_metric.code

      return base_code unless plan.charges.parents.exists?(code: base_code)

      existing_suffixes = plan.charges.parents
        .where("code ~ ?", "^#{Regexp.escape(base_code)}_\\d+$")
        .pluck(:code)
        .map { |code| code.delete_prefix("#{base_code}_").to_i }

      next_suffix = (existing_suffixes.max || 1) + 1

      "#{base_code}_#{next_suffix}"
    end
  end
end
