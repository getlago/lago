# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataExportMailer do
  let(:data_export) { create(:data_export, :completed) }

  describe "#completed" do
    let(:mail) { described_class.with(data_export:).completed }
    let(:file_url) { "https://api.lago.dev/rails/active_storage/blobs/redirect/eyJf" }

    before { allow(data_export).to receive(:file_url).and_return(file_url) }

    describe "subject" do
      subject { mail.subject }

      context "with invoice data export" do
        let(:data_export) { create(:data_export, :completed, resource_type: "invoices") }

        it { is_expected.to eq "Your Lago invoices export is ready!" }
      end

      context "with invoice fee data export" do
        let(:data_export) { create(:data_export, :completed, resource_type: "invoice_fees") }

        it { is_expected.to eq "Your Lago invoice fees export is ready!" }
      end
    end

    describe "recipients" do
      subject { mail.to }

      it { is_expected.to eq [data_export.user.email] }
    end

    describe "body" do
      subject { mail.body.to_s }

      it "includes expiration notice and link to file" do
        expect(subject).to match("will be available for 7 days")
        expect(subject).to match(data_export.file_url)
      end
    end

    describe "delivery" do
      subject { mail.deliver_now }

      let(:deliveries) { ActionMailer::Base.deliveries }

      context "when data export is not completed" do
        let(:data_export) { create(:data_export, :processing) }

        it "is not performed" do
          expect { subject }.not_to change(deliveries, :count)
        end
      end

      context "when data export is completed" do
        let(:data_export) { create(:data_export, :completed) }

        it "is performed" do
          expect { subject }.to change(deliveries, :count).by(1)
        end
      end
    end
  end
end
