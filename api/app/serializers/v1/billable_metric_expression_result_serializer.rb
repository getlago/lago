# frozen_string_literal: true

module V1
  class BillableMetricExpressionResultSerializer < ModelSerializer
    def serialize
      {value: model.evaluation_result}
    end
  end
end
