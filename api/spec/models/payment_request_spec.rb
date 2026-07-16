# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentRequest do
  subject(:payment_request) do
    described_class.new(
      organization:,
      customer:,
      email: Faker::Internet.email,
      amount_cents: Faker::Number.number(digits: 5),
      amount_currency: Faker::Currency.code
    )
  end

  let(:customer) { create(:customer) }
  let(:organization) { customer.organization }
  let(:payment) { create(:payment) }

  it_behaves_like "paper_trail traceable"

  it { is_expected.to have_many(:applied_invoices).class_name("PaymentRequest::AppliedInvoice") }
  it { is_expected.to have_many(:invoices).through(:applied_invoices) }
  it { is_expected.to have_many(:payments) }

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:customer) }
  it { is_expected.to belong_to(:dunning_campaign).optional }

  describe "normalizations" do
    it "sanitizes email on assignment" do
      payment_request.email = " hello@some\u200Bthing\u2013other.com "
      expect(payment_request.email).to eq("hello@something-other.com")
    end
  end

  describe "Validations" do
    it "is valid with valid attributes" do
      expect(payment_request).to be_valid
    end

    it "is not valid without amount_cents" do
      payment_request.amount_cents = nil
      expect(payment_request).not_to be_valid
    end

    it "is not valid without amount_currency" do
      payment_request.amount_currency = nil
      expect(payment_request).not_to be_valid
    end
  end

  describe "#total_amount_cents" do
    it "aliases amount_cents" do
      expect(payment_request.total_amount_cents).to eq(payment_request.amount_cents)
    end
  end

  describe "#total_amount_cents=" do
    let(:amount_cents) { 19_999_55 }

    it "aliases amount_cents=" do
      payment_request.total_amount_cents = amount_cents
      expect(payment_request.amount_cents).to eq(amount_cents)
    end
  end

  describe "#currency" do
    it "aliases amount_currency" do
      expect(payment_request.currency).to eq(payment_request.amount_currency)
    end
  end

  describe "#invoice_ids" do
    let(:payment_request) { create(:payment_request, invoices:) }
    let(:invoices) { create_list(:invoice, 2, organization:) }

    it "returns a list with the applied invoice ids" do
      expect(payment_request.invoice_ids).to eq(invoices.map(&:id))
    end
  end

  describe "#increment_payment_attempts!" do
    let(:payment_request) { create :payment_request }

    it "updates payment_attempts attribute +1" do
      expect { payment_request.increment_payment_attempts! }
        .to change { payment_request.reload.payment_attempts }
        .by(1)
    end
  end
end
