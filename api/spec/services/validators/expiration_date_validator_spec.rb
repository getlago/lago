# frozen_string_literal: true

require "rails_helper"

RSpec.describe Validators::ExpirationDateValidator do
  describe ".valid?" do
    subject { described_class.valid?(expiration_at) }

    context "when expiration_at is blank" do
      let(:expiration_at) { nil }

      it { is_expected.to be true }
    end

    context "when expiration_at is an empty string" do
      let(:expiration_at) { "" }

      it { is_expected.to be true }
    end

    context "when expiration_at is an invalid format" do
      let(:expiration_at) { "invalid-date" }

      it { is_expected.to be false }
    end

    context "when expiration_at is an integer" do
      let(:expiration_at) { 123 }

      it { is_expected.to be false }
    end

    context "when expiration_at is a past date" do
      let(:expiration_at) { (Time.current - 1.day).iso8601 }

      it { is_expected.to be false }
    end

    context "when expiration_at is a past datetime" do
      let(:expiration_at) { (Time.current - 1.hour).iso8601 }

      it { is_expected.to be false }
    end

    context "when expiration_at is today but not in the future" do
      let(:expiration_at) { Time.current.beginning_of_day.iso8601 }

      it { is_expected.to be false }
    end

    context "when expiration_at is a valid future date" do
      let(:expiration_at) { (Time.current + 1.day).iso8601 }

      it { is_expected.to be true }
    end

    context "when expiration_at is a valid future datetime" do
      let(:expiration_at) { (Time.current + 1.hour).iso8601 }

      it { is_expected.to be true }
    end

    context "when expiration_at is an ActiveSupport::TimeWithZone object in the future" do
      let(:expiration_at) { Time.zone.now + 1.day }

      it { is_expected.to be true }
    end

    context "when expiration_at is an ActiveSupport::TimeWithZone object in the past" do
      let(:expiration_at) { Time.zone.now - 1.day }

      it { is_expected.to be false }
    end
  end
end
