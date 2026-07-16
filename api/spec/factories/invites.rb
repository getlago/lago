# frozen_string_literal: true

FactoryBot.define do
  factory :invite do
    organization

    status { "pending" }
    email { Faker::Internet.email }
    token { SecureRandom.hex(20) }
    roles { %w[admin] }

    after(:build) do |invite|
      existing_codes = Role.with_code(*invite.roles).with_organization(invite.organization.id).pluck(:code)
      missing_roles = invite.roles.reject { |code| existing_codes.include?(code) }
      missing_roles.each { |code| create(:role, organization: invite.organization, code:) }
    end
  end
end
