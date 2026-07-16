# frozen_string_literal: true

module V1
  module Invoices
    class MetadataSerializer < ModelSerializer
      def serialize
        {
          lago_id: model.id,
          key: model.key,
          value: model.value,
          created_at: model.created_at.iso8601
        }
      end
    end
  end
end
