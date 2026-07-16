# frozen_string_literal: true

require "rails_helper"

RSpec.describe LagoMcpClient::SseParser do
  subject(:parser) { Class.new { include LagoMcpClient::SseParser }.new }

  describe "#parse_sse_data" do
    it "parses valid JSON data lines" do
      result = parser.parse_sse_data('data: {"foo": "bar"}')
      expect(result).to eq({"foo" => "bar"})
    end

    it "returns nil when JSON parsing fails" do
      result = parser.parse_sse_data("data: invalid json")
      expect(result).to be_nil
    end

    it "returns nil for nil input" do
      expect(parser.parse_sse_data(nil)).to be_nil
    end

    it "returns nil for empty lines" do
      expect(parser.parse_sse_data("")).to be_nil
      expect(parser.parse_sse_data("   ")).to be_nil
      expect(parser.parse_sse_data("\n")).to be_nil
    end

    it "returns nil for non-data lines" do
      expect(parser.parse_sse_data("id: 123")).to be_nil
      expect(parser.parse_sse_data("event: message")).to be_nil
      expect(parser.parse_sse_data(": comment")).to be_nil
    end

    it "strips whitespace from data" do
      result = parser.parse_sse_data("data: {\"key\": \"value\"}  \n")
      expect(result).to eq({"key" => "value"})
    end
  end

  describe "#extract_sse_id" do
    it "extracts id from valid id line" do
      expect(parser.extract_sse_id("id: 123")).to eq("123")
    end

    it "strips whitespace from id" do
      expect(parser.extract_sse_id("id: abc-456  \n")).to eq("abc-456")
    end

    it "returns nil for nil input" do
      expect(parser.extract_sse_id(nil)).to be_nil
    end

    it "returns nil for non-id lines" do
      expect(parser.extract_sse_id("data: foo")).to be_nil
      expect(parser.extract_sse_id("event: message")).to be_nil
    end
  end

  describe "#find_sse_data_line" do
    it "finds the data line in a multi-line body" do
      body = "id: 123\nevent: message\ndata: {\"foo\": \"bar\"}\n"
      expect(parser.find_sse_data_line(body)).to eq("data: {\"foo\": \"bar\"}\n")
    end

    it "returns the first data line when multiple exist" do
      body = "data: first\ndata: second\n"
      expect(parser.find_sse_data_line(body)).to eq("data: first\n")
    end

    it "returns nil when no data line exists" do
      body = "id: 123\nevent: message\n"
      expect(parser.find_sse_data_line(body)).to be_nil
    end

    it "returns nil for nil body" do
      expect(parser.find_sse_data_line(nil)).to be_nil
    end
  end

  describe "#find_sse_id_line" do
    it "finds the id line in a multi-line body" do
      body = "id: 123\nevent: message\ndata: {\"foo\": \"bar\"}\n"
      expect(parser.find_sse_id_line(body)).to eq("id: 123\n")
    end

    it "returns the first id line when multiple exist" do
      body = "id: first\nid: second\n"
      expect(parser.find_sse_id_line(body)).to eq("id: first\n")
    end

    it "returns nil when no id line exists" do
      body = "data: foo\nevent: message\n"
      expect(parser.find_sse_id_line(body)).to be_nil
    end

    it "returns nil for nil body" do
      expect(parser.find_sse_id_line(nil)).to be_nil
    end
  end
end
