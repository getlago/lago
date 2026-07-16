# frozen_string_literal: true

require "rails_helper"

RSpec.describe Regex do
  describe "UUID" do
    it "matches a valid UUID" do
      expect(Regex::UUID).to match("123e4567-e89b-12d3-a456-426614174000")
    end

    it "does not match an invalid UUID" do
      expect(Regex::UUID).not_to match("123e4567-e89b-12d3-a456-4266141740000")
      expect(Regex::UUID).not_to match("string")
    end
  end

  describe "EMAIL" do
    it "matches a valid email" do
      expect(Regex::EMAIL).to match("test@example.com")
    end

    it "does not match an invalid email" do
      expect(Regex::EMAIL).not_to match("test@example.com@invalid")
    end
  end

  describe "INVISIBLE_CHARS" do
    it "matches a valid invisible character" do
      expect(Regex::INVISIBLE_CHARS).to match("\u200B")
      expect(Regex::INVISIBLE_CHARS).to match("\u200C")
      expect(Regex::INVISIBLE_CHARS).to match("\u200D")
      expect(Regex::INVISIBLE_CHARS).to match("\u00A0")
      expect(Regex::INVISIBLE_CHARS).to match("\u200E")
      expect(Regex::INVISIBLE_CHARS).to match("\u200F")
    end
  end

  describe "ISO8601_DATETIME" do
    it "matches a valid ISO8601 datetime" do
      expect(Regex::ISO8601_DATETIME).to match("2022-09-05T12:23:12Z")
      expect(Regex::ISO8601_DATETIME).to match("2022-09-05T12:23:12.123Z")
      expect(Regex::ISO8601_DATETIME).to match("2022-09-05T12:23:12.123+00:00")
    end

    it "does not match an invalid ISO8601 datetime" do
      expect(Regex::ISO8601_DATETIME).not_to match("2022-09-05 12:23:12+00:00")
    end
  end
end
