# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::ApiKeys::SanitizedObject do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:name).of_type("String")
    expect(subject).to have_field(:permissions).of_type("JSON!")
    expect(subject).to have_field(:value).of_type("String!")
    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:expires_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:last_used_at).of_type("ISO8601DateTime")
  end
end
