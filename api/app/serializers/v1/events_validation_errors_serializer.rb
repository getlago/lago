# frozen_string_literal: true

module V1
  class EventsValidationErrorsSerializer < ModelSerializer
    def serialize
      {
        invalid_code: model[:invalid_code],
        missing_aggregation_property: model[:missing_aggregation_property],
        missing_group_key: model[:missing_group_key],
        invalid_filter_values: model[:invalid_filter_values]
      }
    end
  end
end
