# frozen_string_literal: true

FactoryBot.define do
  factory :membership_role do
    membership
    organization { membership.organization }
    role { association :role, organization: }

    %i[admin manager finance].each do |role_trait|
      trait role_trait do
        role { association :role, role_trait }
      end
    end
  end
end
