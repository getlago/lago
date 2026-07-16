# frozen_string_literal: true

class EventsRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: {writing: :events, reading: :events}
end
