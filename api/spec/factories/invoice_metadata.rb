# frozen_string_literal: true

FactoryBot.define do
  factory :invoice_metadata, class: "Metadata::InvoiceMetadata" do
    invoice
    organization { invoice&.organization || association(:organization) }

    key { Faker::Commerce.color }
    value { rand(100) }
  end
end
