# frozen_string_literal: true

require "rails_helper"

RSpec.describe Quote do
  subject(:quote) { create(:quote) }

  describe "enums" do
    it do
      expect(subject).to define_enum_for(:order_type)
        .backed_by_column_of_type(:enum)
        .with_values(
          subscription_creation: "subscription_creation",
          subscription_amendment: "subscription_amendment",
          one_off: "one_off"
        )
        .without_instance_methods
        .validating(allowing_nil: false)
    end
  end

  describe "associations" do
    it do
      expect(subject).to belong_to(:organization)
      expect(subject).to belong_to(:customer)
      expect(subject).to belong_to(:subscription).optional
      expect(subject).to have_many(:quote_owners).dependent(:destroy)
      expect(subject).to have_many(:owners).through(:quote_owners)
      expect(subject).to have_many(:versions).class_name("QuoteVersion").order(sequential_id: :desc)
      expect(subject).to have_one(:current_version).class_name("QuoteVersion").order(sequential_id: :desc)
      expect(subject).to have_many(:order_forms).through(:versions)
      expect(subject).to have_many_attached(:images)
    end
  end

  describe "validations" do
    describe "subscription_id" do
      it "requires subscription_id when order_type is subscription_amendment" do
        organization = create(:organization)
        customer = create(:customer, organization:)
        quote = build(:quote, organization:, customer:, order_type: :subscription_amendment, subscription: nil)
        expect(quote).not_to be_valid
        quote.subscription = create(:subscription, organization:, customer:)
        expect(quote).to be_valid
      end

      it "does not require subscription_id when order_type is subscription_creation" do
        quote = build(:quote, order_type: :subscription_creation, subscription: nil)
        expect(quote).to be_valid
      end

      it "does not require subscription_id when order_type is one_off" do
        quote = build(:quote, order_type: :one_off, subscription: nil)
        expect(quote).to be_valid
      end
    end

    describe "images validation" do
      it do
        expect(quote).to validate_content_type_of(:images)
          .allowing("image/png", "image/jpeg", "image/webp", "image/gif")
          .rejecting("application/pdf", "text/plain")
      end

      it { is_expected.to validate_size_of(:images).less_than(5.megabytes) }
    end
  end

  describe "sequencing" do
    it "assigns sequential ids per organization" do
      organization = create(:organization)
      customer = create(:customer, organization:)
      first = create(:quote, organization:, customer:, sequential_id: nil)
      second = create(:quote, organization:, customer:, sequential_id: nil)
      expect([first.sequential_id, second.sequential_id]).to eq([1, 2])
    end

    it "scopes the sequence per organization" do
      org_a = create(:organization)
      org_b = create(:organization)
      a1 = create(:quote, organization: org_a, customer: create(:customer, organization: org_a), sequential_id: nil)
      b1 = create(:quote, organization: org_b, customer: create(:customer, organization: org_b), sequential_id: nil)
      expect([a1.sequential_id, b1.sequential_id]).to eq([1, 1])
    end
  end

  describe "ensure_number callback" do
    it "assigns a formatted number when sequential_id and created_at are present" do
      quote = create(:quote, sequential_id: 123, number: nil, created_at: Time.zone.local(2020, 1, 2))
      expect(quote.number).to eq("QT-2020-0123")
    end

    it "uses the current year when created_at is blank on save" do
      organization = create(:organization)
      customer = create(:customer, organization:)
      travel_to(Time.zone.local(2026, 6, 1)) do
        quote = build(:quote, organization:, customer:, sequential_id: 7, number: nil, created_at: nil, order_type: :one_off)
        quote.save!
        expect(quote.number).to eq("QT-2026-0007")
      end
    end

    it "preserves an explicitly assigned number" do
      quote = create(:quote, sequential_id: 1, number: "QT-CUSTOM-0001")
      expect(quote.number).to eq("QT-CUSTOM-0001")
    end
  end
end
