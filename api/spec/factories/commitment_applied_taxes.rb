# frozen_string_literal: true

FactoryBot.define do
  factory :commitment_applied_tax, class: "Commitment::AppliedTax" do
    commitment
    tax
    organization { commitment&.organization || tax&.organization || association(:organization) }
  end
end
