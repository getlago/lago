# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::ApiLogs::HttpStatus do
  it "coerce input to integer when possible" do
    expect(described_class.coerce_input("failed", nil)).to eq("failed")
    expect(described_class.coerce_input("succeeded", nil)).to eq("succeeded")

    expect(described_class.coerce_input("404", nil)).to eq(404)
    expect(described_class.coerce_input("200", nil)).to eq(200)
  end

  it "do not coerce result" do
    expect(described_class.coerce_result("failed", nil)).to eq("failed")
    expect(described_class.coerce_result("succeeded", nil)).to eq("succeeded")

    expect(described_class.coerce_result(404, nil)).to eq(404)
    expect(described_class.coerce_result(200, nil)).to eq(200)
  end
end
