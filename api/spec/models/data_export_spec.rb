# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataExport do
  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:membership) }
  it { is_expected.to have_one(:user).through(:membership) }
  it { is_expected.to have_many(:data_export_parts) }

  it { is_expected.to validate_presence_of(:resource_type) }

  specify do
    expect(subject)
      .to define_enum_for(:format)
      .with_values([:csv])
      .validating
  end

  specify do
    expect(subject)
      .to define_enum_for(:status)
      .with_values(%i[pending processing completed failed])
      .validating
  end

  describe "validations" do
    describe "of file being attached" do
      subject { data_export }

      let(:data_export) { build(:data_export, status:) }

      context "when status is completed" do
        let(:status) { "completed" }

        it { is_expected.to validate_attached_of(:file) }
      end

      context "when status is non-completed" do
        let(:status) { described_class::STATUSES.excluding("completed").sample }

        it { is_expected.not_to validate_attached_of(:file) }
      end
    end
  end

  describe "#processing!" do
    subject(:processing!) { data_export.processing! }

    let(:data_export) { create :data_export }

    it "updates status and started_at timestamp" do
      freeze_time do
        expect { processing! }
          .to change(data_export, :status).to("processing")
          .and change(data_export, :started_at).to(Time.zone.now)
      end
    end
  end

  describe "#completed!" do
    subject(:completed!) { data_export.completed! }

    let(:data_export) { create :data_export, :with_file }

    it "updates status and started_at timestamp" do
      freeze_time do
        expect { completed! }
          .to change(data_export, :status).to("completed")
          .and change(data_export, :completed_at).to(Time.zone.now)
          .and change(data_export, :expires_at).to(7.days.from_now)
      end
    end
  end

  describe "#expired?" do
    subject(:expired?) { data_export.expired? }

    let(:data_export) { build_stubbed :data_export }

    it { is_expected.to eq false }

    context "when export is completed" do
      let(:data_export) { build_stubbed :data_export, :completed }

      it { is_expected.to eq false }
    end

    context "when the expiration date is reached" do
      let(:data_export) { build_stubbed :data_export, :expired }

      it { is_expected.to eq true }
    end
  end

  describe "#export_class" do
    let(:data_export) { build_stubbed :data_export, resource_type: }

    context "when resource_type is invoices" do
      let(:resource_type) { "invoices" }

      it "returns DataExports::Csv::Invoices" do
        expect(data_export.export_class).to eq(DataExports::Csv::Invoices)
      end
    end

    context "when resource_type is invoice_fees" do
      let(:resource_type) { "invoice_fees" }

      it "returns DataExports::Csv::InvoiceFees" do
        expect(data_export.export_class).to eq(DataExports::Csv::InvoiceFees)
      end
    end

    context "when resource_type is credit notes" do
      let(:resource_type) { "credit_notes" }

      it "returns DataExports::Csv::CreditNotes" do
        expect(data_export.export_class).to eq(DataExports::Csv::CreditNotes)
      end
    end

    context "when resource_type is credit note items" do
      let(:resource_type) { "credit_note_items" }

      it "returns DataExports::Csv::CreditNotes" do
        expect(data_export.export_class).to eq(DataExports::Csv::CreditNoteItems)
      end
    end

    context "when resource_type is an unsupported value" do
      let(:resource_type) { "unsupported" }

      it "returns nil" do
        expect(data_export.export_class).to eq(nil)
      end
    end
  end

  describe "#filename" do
    subject(:filename) { data_export.filename }

    let(:data_export) { create :data_export, :completed }

    it "returns the file name" do
      freeze_time do
        timestamp = Time.zone.now.strftime("%Y%m%d%H%M%S")
        expect(filename).to eq("#{timestamp}_invoices.csv")
      end
    end

    context "when data export does not have a file" do
      let(:data_export) { create :data_export }

      it "returns the file name" do
        freeze_time do
          timestamp = Time.zone.now.strftime("%Y%m%d%H%M%S")
          expect(filename).to eq("#{timestamp}_invoices.csv")
        end
      end
    end
  end

  describe "#file_url" do
    subject(:file_url) { data_export.file_url }

    let(:data_export) { create :data_export, :completed }

    it "returns the file url" do
      expect(file_url).to be_present
      expect(file_url).to include(ENV["LAGO_API_URL"])
    end

    context "when data export does not have a file" do
      let(:data_export) { create :data_export }

      it { is_expected.to be_nil }
    end
  end
end
