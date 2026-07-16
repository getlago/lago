# frozen_string_literal: true

module V1
  module Customers
    class MetadataSerializer < ModelSerializer
      def serialize
        {
          lago_id: model.id,
          key: model.key,
          value: model.value,
          display_in_invoice: model.display_in_invoice,
          created_at: model.created_at.iso8601
        }
      end
    end
  end
end
