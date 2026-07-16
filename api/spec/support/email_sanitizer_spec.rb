# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmailSanitizer do
  describe ".call" do
    it "returns nil-safe for blank input" do
      expect(described_class.call(nil)).to be_nil
      expect(described_class.call("")).to eq("")
    end

    it "returns a valid email unchanged" do
      expect(described_class.call("hello@example.com")).to eq("hello@example.com")
    end

    it "replaces en-dash with hyphen" do
      expect(described_class.call("hello@something\u2013other.com")).to eq("hello@something-other.com")
    end

    it "replaces em-dash with hyphen" do
      expect(described_class.call("hello@something\u2014other.com")).to eq("hello@something-other.com")
    end

    it "removes zero-width space" do
      expect(described_class.call("hello@some\u200Bthing.com")).to eq("hello@something.com")
    end

    it "removes zero-width non-joiner" do
      expect(described_class.call("hello@some\u200Cthing.com")).to eq("hello@something.com")
    end

    it "removes zero-width joiner" do
      expect(described_class.call("hello@some\u200Dthing.com")).to eq("hello@something.com")
    end

    it "removes non-breaking space" do
      expect(described_class.call("hello@some\u00A0thing.com")).to eq("hello@something.com")
    end

    it "removes left-to-right mark" do
      expect(described_class.call("hello@some\u200Ething.com")).to eq("hello@something.com")
    end

    it "removes right-to-left mark" do
      expect(described_class.call("hello@some\u200Fthing.com")).to eq("hello@something.com")
    end

    it "removes BOM character" do
      expect(described_class.call("\uFEFFhello@example.com")).to eq("hello@example.com")
    end

    it "strips leading and trailing whitespace" do
      expect(described_class.call("  hello@example.com  ")).to eq("hello@example.com")
    end

    it "handles multiple issues combined" do
      expect(described_class.call(" hello@something\u2013other\u200B.com ")).to eq("hello@something-other.com")
    end
  end
end
