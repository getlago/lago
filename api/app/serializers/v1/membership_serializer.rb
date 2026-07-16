# frozen_string_literal: true

module V1
  class MembershipSerializer < ModelSerializer
    def serialize
      {
        lago_id: model.id,
        lago_user_id: model.user_id,
        lago_organization_id: model.organization_id,
        roles: model.roles.pluck(:name)
      }
    end
  end
end
