# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::IntegrationCollectionMappings::CurrencyMappingItem do
  subject { described_class }

  it do
    expect(subject).to have_field(:currency_code).of_type("CurrencyEnum!")
    expect(subject).to have_field(:currency_external_code).of_type("String!")
  end
end
