# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Organizations::OrganizationType do
  subject { described_class }

  it do
    expect(subject).to be < ::Types::Organizations::BaseOrganizationType

    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:logo_url).of_type("String")
    expect(subject).to have_field(:name).of_type("String!")
    expect(subject).to have_field(:slug).of_type("String!")
    expect(subject).to have_field(:timezone).of_type("TimezoneEnum")
    expect(subject).to have_field(:default_currency).of_type("CurrencyEnum!")
    expect(subject).to have_field(:can_create_billing_entity).of_type("Boolean!")
    expect(subject).to have_field(:accessible_by_current_session).of_type("Boolean!")
  end
end
