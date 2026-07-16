# frozen_string_literal: true

FactoryBot.define do
  factory :membership do
    user
    organization

    transient do
      role {}
      roles { [] }
    end

    trait :revoked do
      status { :revoked }
      revoked_at { Time.current }
    end

    after(:create) do |membership, evaluator|
      if evaluator.role.present?
        create(:membership_role, role: evaluator.role, membership:)
      end

      evaluator.roles.each do |role_trait|
        create(:membership_role, role_trait.to_sym, membership:)
      end
    end
  end
end
