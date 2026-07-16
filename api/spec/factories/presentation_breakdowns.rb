# frozen_string_literal: true

FactoryBot.define do
  factory :presentation_breakdown do
    organization { fee&.organization || association(:organization) }
    fee factory: :charge_fee
    units { 60.0 }
    presentation_by do
      {department: "engineering"}
    end

    trait :with_composite_presentation_by do
      presentation_by do
        {department: "engineering", region: "eu"}
      end
    end
  end
end
