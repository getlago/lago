# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Integrations::Okta do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")

    expect(subject).to have_field(:client_id).of_type("String")
    expect(subject).to have_field(:client_secret).of_type("ObfuscatedString")
    expect(subject).to have_field(:code).of_type("String!")
    expect(subject).to have_field(:domain).of_type("String!")
    expect(subject).to have_field(:name).of_type("String!")
    expect(subject).to have_field(:organization_name).of_type("String!")
    expect(subject).to have_field(:host).of_type("String")
  end

  it "ensure all fields are tested" do
    expect(subject.fields.values.map(&:original_name) -
      %i[id client_id client_secret code domain name organization_name host]).to be_empty
  end
end
