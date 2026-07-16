# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::WalletTransactions::MetadataObject do
  subject { described_class }

  it "has the expected fields" do
    expect(subject).to have_field(:key).of_type("String!")
    expect(subject).to have_field(:value).of_type("String!")
  end
end
