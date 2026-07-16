# frozen_string_literal: true

module V1
  class QuoteSerializer < ModelSerializer
    def serialize
      payload = {
        lago_id: model.id,
        number: model.number,
        order_type: model.order_type,
        lago_customer_id: model.customer_id,
        lago_subscription_id: model.subscription_id,
        lago_organization_id: model.organization_id,
        created_at: model.created_at.iso8601,
        updated_at: model.updated_at.iso8601
      }.merge(current_version)

      payload.merge!(owners) if include?(:owners)
      payload
    end

    private

    def current_version
      version = model.current_version

      {
        current_version: version && ::V1::QuoteVersionSerializer.new(version).serialize
      }
    end

    def owners
      {
        owners: model.owners.map { |owner| {lago_id: owner.id, email: owner.email} }
      }
    end
  end
end
