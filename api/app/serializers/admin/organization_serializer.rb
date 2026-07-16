# frozen_string_literal: true

module Admin
  class OrganizationSerializer < ModelSerializer
    def serialize
      {
        id: model.id,
        name: model.name,
        document_numbering: model.document_numbering,
        premium_integrations: model.premium_integrations,
        created_at: model.created_at.iso8601,
        updated_at: model.updated_at.iso8601
      }
    end
  end
end
