# frozen_string_literal: true

FactoryBot.define do
  factory :item_metadata, class: "Metadata::ItemMetadata" do
    organization
    owner { association :credit_note, organization: }
    value { {"key" => "value"} }
  end
end
