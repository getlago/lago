# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Orders::UpdateInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:execute_at).of_type("ISO8601DateTime")
    expect(subject).to accept_argument(:execution_mode).of_type("OrderExecutionModeEnum")
    expect(subject).to accept_argument(:id).of_type("ID!")
  end
end
