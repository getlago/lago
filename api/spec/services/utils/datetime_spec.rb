# frozen_string_literal: true

require "rails_helper"

RSpec.describe Utils::Datetime do
  subject(:datetime) { described_class }

  describe ".datetime_like?" do
    context "when the value is a datetime-like object" do
      it "returns true for every datetime-like class" do
        [Time.current.to_time, Time.current, Date.current, DateTime.now].each do |value|
          expect(datetime.datetime_like?(value)).to be true
        end
      end
    end

    context "when the value is not datetime-like" do
      it "returns false" do
        expect(datetime.datetime_like?("2022-12-13")).to be false
        expect(datetime.datetime_like?(123)).to be false
        expect(datetime.datetime_like?(nil)).to be false
      end
    end
  end

  describe ".parse_iso8601" do
    context "when the value is an ISO8601 string" do
      let(:value) { "2022-12-13T12:00:00Z" }

      it "returns the parsed datetime" do
        expect(datetime.parse_iso8601(value)).to eq(DateTime.iso8601(value))
      end
    end

    context "when the value is already date-like" do
      it "returns the value unchanged for every datetime-like class" do
        [Time.current.to_time, Time.current, Date.current, DateTime.now].each do |value|
          expect(datetime.parse_iso8601(value)).to eq(value)
        end
      end
    end

    context "when the value is a malformed string" do
      let(:value) { "not-a-date" }

      it "returns nil" do
        expect(datetime.parse_iso8601(value)).to be_nil
      end
    end

    context "when the value raises a bare ArgumentError" do
      let(:value) { "1" * 129 }

      it "returns nil" do
        expect(datetime.parse_iso8601(value)).to be_nil
      end
    end

    context "when the value is not a string or date-like object" do
      it "returns nil" do
        expect(datetime.parse_iso8601(123)).to be_nil
      end
    end
  end

  describe ".parse_iso8601_date" do
    context "when the value is an ISO8601 date string" do
      let(:value) { "2022-12-13" }

      it "returns the parsed date" do
        expect(datetime.parse_iso8601_date(value)).to eq(Date.iso8601(value))
      end
    end

    context "when the value is already date-like" do
      it "returns it as a date for every datetime-like class" do
        [Time.current.to_time, Time.current, Date.current, DateTime.now].each do |value|
          expect(datetime.parse_iso8601_date(value)).to eq(value.to_date)
        end
      end
    end

    context "when the value is a malformed string" do
      let(:value) { "not-a-date" }

      it "returns nil" do
        expect(datetime.parse_iso8601_date(value)).to be_nil
      end
    end

    context "when the value raises a bare ArgumentError" do
      let(:value) { "1" * 129 }

      it "returns nil" do
        expect(datetime.parse_iso8601_date(value)).to be_nil
      end
    end
  end

  describe ".valid_format?" do
    context "when the parameter is a string" do
      context "when the date is not in ISO8601 format" do
        it "returns false for invalid format" do
          expect(datetime).not_to be_valid_format("2022-12-13 12:00:00Z")
        end
      end

      context "when the date is in ISO8601 format" do
        it "returns true" do
          expect(datetime).to be_valid_format("2022-12-13T12:00:00Z")
        end
      end

      context "when the date includes microseconds" do
        it "returns true" do
          expect(datetime).to be_valid_format("2024-05-30T09:45:44.394316274Z")
        end
      end

      context "when the date raises a bare ArgumentError" do
        it "returns false" do
          expect(datetime).not_to be_valid_format("1" * 129)
        end
      end

      context "when the date is in ISO8601 week-date format" do
        it "returns false" do
          expect(datetime).not_to be_valid_format("2022-W50-2")
        end
      end
    end

    context "when the parameter is neither a string nor a datetime object" do
      it "returns false" do
        expect(datetime).not_to be_valid_format(123)
      end
    end

    context "when the parameter is a datetime object" do
      it "returns true for every datetime-like class" do
        [Time.current.to_time, Time.current, Date.current, DateTime.now].each do |value|
          expect(datetime).to be_valid_format(value)
        end
      end
    end

    context "when :any format is specified" do
      context "when the date format is valid" do
        it "returns true" do
          expect(datetime).to be_valid_format("2022-12-13T12:00:00Z", format: :any)
          expect(datetime).to be_valid_format("2022-12-13 12:00:00Z", format: :any)
        end
      end

      context "when the date is invalid" do
        it "returns false" do
          expect(datetime).not_to be_valid_format("aaa", format: :any)
        end
      end
    end
  end

  describe ".future_date?" do
    context "when the date is in the future" do
      it "returns true" do
        expect(datetime).to be_future_date("2064-12-13T12:00:00Z")
        expect(datetime).to be_future_date("2064-12-13 12:00:00")
        expect(datetime).to be_future_date("2064-12-13")
      end
    end

    context "when the date is in the past" do
      it "returns false" do
        expect(datetime).not_to be_future_date("2022-12-13T12:00:00Z")
        expect(datetime).not_to be_future_date("2022-12-13 12:00:00")
        expect(datetime).not_to be_future_date("2022-12-13")
      end
    end

    context "when the format is invalid" do
      it "returns false" do
        expect(datetime).not_to be_future_date("aaa")
      end
    end

    context "when the date is an ActiveSupport::TimeWithZone" do
      context "when the date is in the future" do
        it "returns true" do
          expect(datetime).to be_future_date(Time.current + 1.day)
        end
      end

      context "when the date is in the past" do
        it "returns false" do
          expect(datetime).not_to be_future_date(Time.current - 1.day)
        end
      end
    end
  end

  describe ".date_diff_with_timezone" do
    let(:from_datetime) { Time.zone.parse("2023-08-31T23:10:00") }
    let(:to_datetime) { Time.zone.parse("2023-09-30T22:59:59") }
    let(:timezone) { "Europe/Paris" }

    let(:result) do
      datetime.date_diff_with_timezone(
        from_datetime,
        to_datetime,
        timezone
      )
    end

    it "returns the number of days between the two datetime" do
      expect(result).to eq(30)
    end

    context "with positive daylight saving time" do
      let(:from_datetime) { Time.zone.parse("2023-09-30T23:10:00") }
      let(:to_datetime) { Time.zone.parse("2023-10-31T22:59:59") }
      let(:timezone) { "Europe/Paris" }

      it "takes the daylight saving time into account" do
        expect(result).to eq(31)
      end
    end

    context "with negative daylight saving time" do
      let(:from_datetime) { Time.zone.parse("2023-02-28T23:10:00") }
      let(:to_datetime) { Time.zone.parse("2023-03-31T21:59:59") }
      let(:timezone) { "Europe/Paris" }

      it "takes the daylight saving time into account" do
        expect(result).to eq(31)
      end
    end

    context "with to date is the beginning of the day" do
      let(:from_datetime) { Time.zone.parse("2023-12-01T00:00:00") }
      let(:to_datetime) { Time.zone.parse("2023-12-07T00:00:00") }
      let(:timezone) { "UTC" }

      it "ensures it counts the full days" do
        expect(result).to eq(7)
      end
    end

    context "with to date at the beginning of the day in timezone" do
      let(:from_datetime) { Time.zone.parse("2023-12-01T00:00:00").in_time_zone(timezone).beginning_of_day.utc }
      let(:to_datetime) { Time.zone.parse("2023-12-07T00:00:00").in_time_zone(timezone).beginning_of_day.utc }
      let(:timezone) { "America/New_York" }

      it "ensures it counts the full days" do
        expect(result).to eq(7)
      end
    end
  end
end
