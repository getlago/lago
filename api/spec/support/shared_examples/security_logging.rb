# frozen_string_literal: true

RSpec.shared_examples "produces a security log" do |event|
  it "produces a security log" do
    expect(security_logger).to have_received(:produce).with(hash_including(log_event: event)).at_least(:once)
  end
end

RSpec.shared_examples "does not produce a security log" do
  it "does not produce a security log" do
    expect(security_logger).not_to have_received(:produce)
  end
end
