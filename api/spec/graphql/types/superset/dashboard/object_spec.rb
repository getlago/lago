# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Superset::Dashboard::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("String!")
    expect(subject).to have_field(:dashboard_title).of_type("String!")
    expect(subject).to have_field(:embedded_id).of_type("String!")
    expect(subject).to have_field(:guest_token).of_type("String!")
    expect(subject).to have_field(:superset_url).of_type("String!")
  end
end
