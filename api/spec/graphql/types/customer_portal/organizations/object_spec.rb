# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::CustomerPortal::Organizations::Object do
  subject { described_class }

  it do
    expect(subject).to be < ::Types::Organizations::BaseOrganizationType

    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:billing_configuration).of_type("OrganizationBillingConfiguration")
    expect(subject).to have_field(:default_currency).of_type("CurrencyEnum!")
    expect(subject).to have_field(:logo_url).of_type("String")
    expect(subject).to have_field(:name).of_type("String!")
    expect(subject).to have_field(:premium_integrations).of_type("[PremiumIntegrationTypeEnum!]!")
    expect(subject).to have_field(:timezone).of_type("TimezoneEnum")
  end
end
