# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::InvoiceCustomSections::UpdateInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:id).of_type("ID!")

    expect(subject).to accept_argument(:description).of_type("String")
    expect(subject).to accept_argument(:details).of_type("String")
    expect(subject).to accept_argument(:display_name).of_type("String")
    expect(subject).to accept_argument(:name).of_type("String")
  end
end
