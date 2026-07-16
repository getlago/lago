# frozen_string_literal: true

require "rails_helper"

RSpec.describe Utils::PdfAttachmentService do
  let(:file) { instance_double(File, path: "/tmp/test.pdf") }
  let(:attachment) { instance_double(File, path: "/tmp/test.xml") }

  describe "#call" do
    subject { described_class.new(file:, attachment:).call }

    it "add the attachment to pdf" do
      allow(Kernel).to receive(:system).with("pdfcpu", "attach", "add", file.path, attachment.path).and_return(true)
      allow(File).to receive(:file?).with(file).and_return(true)
      allow(File).to receive(:file?).with(attachment).and_return(true)

      result = subject
      expect(result).to be_success
      expect(result.file).to eq(file)
    end

    context "when file param is not a file" do
      let(:file) { "" }

      it "fails" do
        allow(File).to receive(:file?).with(file).and_call_original

        result = subject
        expect(result).to be_failure
        expect(result.error.message).to eq("file_not_found")
      end
    end

    context "when file param is not a pdf" do
      let(:file) { instance_double(File, path: "/tmp/test.doc") }

      it "fails" do
        allow(File).to receive(:file?).with(file).and_return(true)

        result = subject
        expect(result).to be_failure
        expect(result.error.message).to eq("not_a_pdf_file")
      end
    end

    context "when attachment param is not a file" do
      let(:attachment) { "" }

      before { attachment }

      it "fails" do
        allow(File).to receive(:file?).with(file).and_return(true)
        allow(File).to receive(:file?).with(attachment).and_call_original

        result = subject
        expect(result).to be_failure
        expect(result.error.message).to eq("attachment_not_found")
      end
    end
  end
end
