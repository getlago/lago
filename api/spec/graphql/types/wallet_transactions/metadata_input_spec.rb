# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::WalletTransactions::MetadataInput do
  subject { described_class }

  it "has the expected arguments" do
    expect(subject).to accept_argument(:key).of_type("String!")
    expect(subject).to accept_argument(:value).of_type("String!")
  end
end
