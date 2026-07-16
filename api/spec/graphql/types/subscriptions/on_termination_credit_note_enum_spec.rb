# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Subscriptions::OnTerminationCreditNoteEnum do
  it "enumerates the correct values" do
    expect(described_class.values.keys).to match_array(%w[skip credit refund offset])
  end
end
