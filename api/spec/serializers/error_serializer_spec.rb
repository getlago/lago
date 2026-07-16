# frozen_string_literal: true

require "rails_helper"

RSpec.describe ErrorSerializer do
  subject(:serializer) { described_class.new(error) }

  let(:error) { StandardError.new("Something went wrong") }

  it "has a default serialization" do
    expect(serializer.error).to eq(error)
    expect(serializer.serialize).to eq(
      message: "Something went wrong"
    )
  end
end
