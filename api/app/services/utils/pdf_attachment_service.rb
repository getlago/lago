# frozen_string_literal: true

module Utils
  class PdfAttachmentService < BaseService
    def initialize(file:, attachment:)
      @file = file
      @attachment = attachment

      super
    end

    def call
      return result.not_found_failure!(resource: "file") unless File.file?(file)
      return result.not_allowed_failure!(code: "not_a_pdf_file") unless file.path.downcase.ends_with?(".pdf")
      return result.not_found_failure!(resource: "attachment") unless File.file?(attachment)

      success = Kernel.system("pdfcpu", "attach", "add", file.path, attachment.path)

      if success
        result.file = file
      else
        result.third_party_failure!(third_party: "pdfcpu", error_code: "failed", error_message: "")
      end

      result
    end

    private

    attr_reader :file, :attachment
  end
end
