# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::InvoiceCustomSections::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:organization).of_type("Organization")

    expect(subject).to have_field(:code).of_type("String!")
    expect(subject).to have_field(:description).of_type("String")
    expect(subject).to have_field(:details).of_type("String")
    expect(subject).to have_field(:display_name).of_type("String")
    expect(subject).to have_field(:name).of_type("String!")
  end
end
