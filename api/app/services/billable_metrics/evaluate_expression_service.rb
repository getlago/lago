# frozen_string_literal: true

module BillableMetrics
  class EvaluateExpressionService < BaseService
    Result = BaseResult[:evaluation_result]

    def initialize(expression:, event:)
      @expression = expression
      @event = event || {}
      super
    end

    def call
      if expression.blank?
        return result.single_validation_failure!(field: "expression", error_code: "value_is_mandatory")
      end

      expression_validation_result = Lago::ExpressionParser.validate(expression)
      if expression_validation_result.present?
        return result.single_validation_failure!(field: "expression", error_code: "invalid_expression")
      end

      evaluation_event = Lago::Event.new(
        event["code"].to_s,
        (event["timestamp"] || Time.current).to_i,
        event["properties"]&.transform_values(&:to_s) || {}
      )

      result.evaluation_result = Lago::ExpressionParser.parse(expression).evaluate(evaluation_event)
      result
    rescue RuntimeError
      result.single_validation_failure!(field: "event", error_code: "invalid_event")
    end

    private

    attr_reader :expression, :event
  end
end
