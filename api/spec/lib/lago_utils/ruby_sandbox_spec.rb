# frozen_string_literal: true

require "rails_helper"

RSpec.describe LagoUtils::RubySandbox do
  let(:code) { <<~RUBY }
    input = { 'a' => 1, 'b' => 2 }

    input.values.sum
  RUBY

  it "runs the code" do
    expect(described_class.run(code)).to eq(3)
  end

  context "with method definition" do
    let(:code) { <<~RUBY }
      def sum(a, b)
        a + b
      end

      sum(1, 2)
    RUBY

    it "runs the code" do
      expect(described_class.run(code)).to eq(3)
    end
  end

  context "when code requires a library" do
    let(:code) { <<~RUBY }
      require 'json'

      { 'a' => 1, 'b' => 2 }.to_json
    RUBY

    it "raises an error" do
      expect { described_class.run(code) }.to raise_error(LagoUtils::RubySandbox::SandboxError)
    end
  end

  context "when code is calling a blacklisted method" do
    let(:code) { <<~RUBY }
      Kernel.exit
    RUBY

    it "raises an error" do
      expect { described_class.run(code) }.to raise_error(LagoUtils::RubySandbox::SandboxError)
    end
  end

  context "when code is executing an external script" do
    let(:code) { <<~RUBY }
      `rm -rf /tmp`
    RUBY

    it "raises an error" do
      expect { described_class.run(code) }.to raise_error(LagoUtils::RubySandbox::SandboxError)
    end
  end
end
