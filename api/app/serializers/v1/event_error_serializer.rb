# frozen_string_literal: true

module V1
  class EventErrorSerializer < ModelSerializer
    def serialize
      payload = {
        status: 422,
        error: "Unprocessable entity",
        message: model.error.to_json
      }

      payload.merge!(event)
    end

    private

    def event
      {event: ::V1::EventSerializer.new(model.event).serialize}
    end
  end
end
