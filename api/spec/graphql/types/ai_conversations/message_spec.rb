# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::AiConversations::Message do
  subject { described_class }

  it do
    expect(subject).to have_field(:content).of_type("String!")
    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:type).of_type("String!")
  end
end
