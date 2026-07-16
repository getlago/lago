# frozen_string_literal: true

module V1
  class TaxSerializer < ModelSerializer
    def serialize
      {
        lago_id: model.id,
        name: model.name,
        code: model.code,
        rate: model.rate,
        description: model.description,
        applied_to_organization: model.applied_to_organization,
        add_ons_count: 0,
        customers_count: 0,
        plans_count: 0,
        charges_count: 0,
        commitments_count: 0,
        created_at: model.created_at.iso8601
      }
    end
  end
end
