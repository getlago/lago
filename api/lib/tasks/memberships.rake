# frozen_string_literal: true

namespace :memberships do
  desc "Revoke duplicates memberships"
  task revoke_duplicates: :environment do
    duplicated_memberships = Membership.active
      .group(:user_id, :organization_id)
      .having("count(*) > 1")
      .select(:user_id, :organization_id)

    duplicated_memberships.each do |membership|
      memberships = Membership.where(
        user_id: membership.user_id,
        organization_id: membership.organization_id
      ).order("created_at ASC")

      memberships.first.mark_as_revoke!
    end
  end
end
