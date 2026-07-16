# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrderForm do
  subject(:order_form) { build(:order_form, quote_version: nil) }

  describe "enums" do
    it do
      expect(order_form).to define_enum_for(:status)
        .backed_by_column_of_type(:enum)
        .validating
        .with_values(generated: "generated", signed: "signed", expired: "expired", voided: "voided")
        .with_default(:generated)

      expect(order_form).to define_enum_for(:void_reason)
        .backed_by_column_of_type(:enum)
        .validating(allowing_nil: true)
        .with_values(manual: "manual", expired: "expired", invalid: "invalid")
        .without_instance_methods
    end
  end

  describe "associations" do
    it do
      expect(order_form).to belong_to(:organization)
      expect(order_form).to belong_to(:customer)
      expect(order_form).to belong_to(:quote_version)
      expect(order_form).to have_one(:quote).through(:quote_version)
      expect(order_form).to have_one(:order)
    end
  end

  describe "Scopes" do
    describe ".expirable" do
      let(:organization) { create(:organization) }
      let(:customer) { create(:customer, organization:) }

      let!(:expired_yesterday) { create(:order_form, :expired_yesterday, organization:, customer:) }

      before do
        create(:order_form, :expiring_tomorrow, organization:, customer:)
        create(:order_form, organization:, customer:, expires_at: nil)
        create(:order_form, :expired, organization:, customer:)
        create(:order_form, :voided, organization:, customer:)
        create(:order_form, :signed, organization:, customer:)
      end

      it "returns only generated order forms past their expires_at" do
        expect(described_class.expirable).to match_array([expired_yesterday])
      end

      context "with customer timezone" do
        let(:customer) { create(:customer, organization:, timezone: "America/New_York") }

        it "includes a form whose expiry day has started in the customer timezone but not in UTC" do
          # 2026-01-16 02:00 UTC is 2026-01-15 21:00 in New York
          form = create(:order_form, organization:, customer:, expires_at: Time.zone.parse("2026-01-16 02:00:00"))

          # Jan 15 everywhere; the expiry day has started only in New York terms
          travel_to(Time.zone.parse("2026-01-15 23:30:00")) do
            expect(described_class.expirable).to include(form)
          end
        end

        it "excludes a form whose expiry day has started in UTC but not in the customer timezone" do
          # 2026-01-16 06:00 UTC is 2026-01-16 01:00 in New York
          form = create(:order_form, organization:, customer:, expires_at: Time.zone.parse("2026-01-16 06:00:00"))

          # already Jan 16 in UTC, still Jan 15 in New York
          travel_to(Time.zone.parse("2026-01-16 04:00:00")) do
            expect(described_class.expirable).not_to include(form)
          end
        end
      end
    end
  end

  describe "validations" do
    describe "void_reason validation" do
      it "requires void_reason when voided" do
        order_form = build(:order_form, status: :voided, void_reason: nil)
        order_form.valid?
        expect(order_form.errors.added?(:void_reason, :blank)).to be(true)
      end

      it "allows a blank void_reason when not voided" do
        order_form = build(:order_form, status: :generated, void_reason: nil)
        order_form.valid?
        expect(order_form.errors.added?(:void_reason, :blank)).to be(false)
      end
    end

    describe "signed_document validation" do
      it do
        expect(order_form).to validate_content_type_of(:signed_document)
          .allowing("application/pdf", "image/jpeg", "image/png")
          .rejecting("image/gif", "text/plain")
      end

      it { is_expected.to validate_size_of(:signed_document).less_than(10.megabytes) }
    end
  end

  describe "sequencing" do
    it "assigns sequential ids per organization" do
      organization = create(:organization)
      customer = create(:customer, organization:)
      first = create(:order_form, organization:, customer:)
      second = create(:order_form, organization:, customer:)
      expect([first.sequential_id, second.sequential_id]).to eq([1, 2])
    end

    it "scopes the sequence per organization" do
      org_a = create(:organization)
      org_b = create(:organization)
      a1 = create(:order_form, organization: org_a, customer: create(:customer, organization: org_a))
      b1 = create(:order_form, organization: org_b, customer: create(:customer, organization: org_b))
      expect([a1.sequential_id, b1.sequential_id]).to eq([1, 1])
    end
  end

  describe "ensure_number callback" do
    it "assigns a formatted number when sequential_id and created_at are present" do
      order_form = create(:order_form, created_at: Time.zone.local(2020, 1, 2))
      expect(order_form.number).to eq("OF-2020-#{format("%04d", order_form.sequential_id)}")
    end

    it "uses the current year when created_at is blank on save" do
      travel_to(Time.zone.local(2026, 6, 1)) do
        order_form = create(:order_form, created_at: nil)
        expect(order_form.number).to eq("OF-2026-#{format("%04d", order_form.sequential_id)}")
      end
    end

    it "preserves an explicitly assigned number" do
      order_form = create(:order_form, number: "OF-CUSTOM-0001")
      expect(order_form.number).to eq("OF-CUSTOM-0001")
    end
  end

  describe "#signed_document_url" do
    it "returns nil when no document is attached" do
      expect(order_form.signed_document_url).to be_nil
    end

    it "returns a blob url when a document is attached" do
      order_form = create(:order_form, :with_signed_document)
      expect(order_form.signed_document_url).to include("/rails/active_storage/blobs")
    end

    it "returns nil when the attached document is not persisted yet" do
      order_form.signed_document.attach(io: StringIO.new("pdf"), filename: "doc", content_type: "application/pdf")
      expect(order_form.signed_document_url).to be_nil
    end
  end
end
