# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::PaymentProviders::Cashfree do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:code).of_type("String!")
    expect(subject).to have_field(:name).of_type("String!")

    expect(subject).to have_field(:client_id).of_type("String").with_permission("organization:integrations:view")
    expect(subject).to have_field(:client_secret).of_type("String").with_permission("organization:integrations:view")
    expect(subject).to have_field(:success_redirect_url).of_type("String").with_permission("organization:integrations:view")
  end
end
