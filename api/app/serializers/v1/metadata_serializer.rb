# frozen_string_literal: true

module V1
  class MetadataSerializer < ModelSerializer
    def serialize
      model&.value
    end
  end
end
