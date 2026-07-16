# frozen_string_literal: true

module V1
  class ActivityLogSerializer < ModelSerializer
    def serialize
      {
        activity_id: model.activity_id,
        activity_type: model.activity_type,
        activity_source: model.activity_source,
        activity_object: model.activity_object,
        activity_object_changes: model.activity_object_changes,
        user_email: model.user&.email,
        resource_id: model.resource_id,
        resource_type: model.resource_type,
        external_customer_id: model.external_customer_id,
        external_subscription_id: model.external_subscription_id,
        logged_at: model.logged_at.iso8601,
        created_at: model.created_at.iso8601
      }
    end
  end
end
