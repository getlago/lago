# frozen_string_literal: true

module Events
  class CalculateExpressionService < BaseService
    Result = BaseResult[:event]

    def initialize(organization:, event:)
      @organization = organization
      @event = event
      super
    end

    def call
      result.event = event

      field_name, expression = BillableMetrics::ExpressionCacheService.call(organization.id, event.code) do
        bm = organization.billable_metrics.with_expression.find_by(code: event.code)
        [bm&.field_name, bm&.expression]
      end
      return result if expression.blank?

      evaluation_event = Lago::Event.new(event.code, event.timestamp.to_i, event.properties)

      # The expression can always be parsed, otherwise it would not be saved.
      value = Lago::ExpressionParser.parse(expression).evaluate(evaluation_event)
      event.properties[field_name] = value

      result
    rescue RuntimeError => e
      result.service_failure!(code: :expression_evaluation_failed, message: e.message)
    end

    private

    attr_reader :organization, :event
  end
end
