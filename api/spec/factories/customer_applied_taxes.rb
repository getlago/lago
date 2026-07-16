# frozen_string_literal: true

FactoryBot.define do
  factory :customer_applied_tax, class: "Customer::AppliedTax" do
    customer
    tax
    organization { customer&.organization || tax&.organization || association(:organization) }
  end
end
