# frozen_string_literal: true

FactoryBot.define do
  factory :role do
    sequence(:code) { |n| "role_#{n}" }
    name { code&.to_s&.camelize || Faker::Job.unique.title }
    custom

    trait :custom do
      organization { create(:organization) }
      permissions { %w[organization:view] }
    end

    trait :predefined do
      organization { nil }
      permissions { [] }
    end

    trait :admin do
      predefined
      code { "admin" }
      name { "Admin" }
      admin { true }
    end

    trait :finance do
      predefined
      code { "finance" }
      name { "Finance" }
    end

    trait :manager do
      predefined
      code { "manager" }
      name { "Manager" }
    end

    to_create do |instance|
      instance.id = Role.unscoped.with_code(instance.code).with_organization(instance.organization&.id).first&.id
      if instance.id
        instance.instance_variable_set(:@new_record, false)
        instance.reload
      else
        instance.save(validate: false)
      end
    end
  end
end
