# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::IntegrationCollectionMappings::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:billing_entity_id).of_type("ID")
    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:integration_id).of_type("ID!")
    expect(subject).to have_field(:mapping_type).of_type("MappingTypeEnum!")

    expect(subject).to have_field(:external_account_code).of_type("String")
    expect(subject).to have_field(:external_id).of_type("String")
    expect(subject).to have_field(:external_name).of_type("String")

    expect(subject).to have_field(:tax_code).of_type("String")
    expect(subject).to have_field(:tax_nexus).of_type("String")
    expect(subject).to have_field(:tax_type).of_type("String")

    expect(subject).to have_field(:currencies).of_type("[CurrencyMappingItem!]")
  end
end
