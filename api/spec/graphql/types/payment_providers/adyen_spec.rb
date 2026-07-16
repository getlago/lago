# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::PaymentProviders::Adyen do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:code).of_type("String!")
    expect(subject).to have_field(:name).of_type("String!")

    expect(subject).to have_field(:api_key).of_type("ObfuscatedString").with_permission("organization:integrations:view")
    expect(subject).to have_field(:hmac_key).of_type("ObfuscatedString").with_permission("organization:integrations:view")
    expect(subject).to have_field(:live_prefix).of_type("String").with_permission("organization:integrations:view")
    expect(subject).to have_field(:merchant_account).of_type("String").with_permission("organization:integrations:view")
    expect(subject).to have_field(:success_redirect_url).of_type("String").with_permission("organization:integrations:view")
  end
end
