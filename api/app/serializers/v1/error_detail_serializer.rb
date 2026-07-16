# frozen_string_literal: true

module V1
  class ErrorDetailSerializer < ModelSerializer
    def serialize
      {
        lago_id: model.id,
        error_code: model.error_code,
        details: model.details
      }
    end
  end
end
