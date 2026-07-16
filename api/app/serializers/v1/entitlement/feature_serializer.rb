# frozen_string_literal: true

module V1
  module Entitlement
    class FeatureSerializer < ModelSerializer
      def serialize
        {
          code: model.code,
          name: model.name,
          description: model.description,
          privileges: privileges,
          created_at: model.created_at.iso8601
        }
      end

      private

      def privileges
        model.privileges.map do |privilege|
          {
            code: privilege.code,
            name: privilege.name,
            value_type: privilege.value_type,
            config: privilege.config
          }
        end
      end
    end
  end
end
