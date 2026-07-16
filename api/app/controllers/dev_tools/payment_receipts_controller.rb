# frozen_string_literal: true

module DevTools
  class PaymentReceiptsController < ApplicationController
    def show
      service = ::PaymentReceipts::GeneratePdfService.new(payment_receipt:)

      # For PDFs we need to use a simple file name and the file is passed to `gotenberg`
      # In order to reuse the exact same template to display in HTML, we replace the image path
      html = service.render_html.gsub('src="lago-logo-invoice.png', 'src="/assets/images/lago-logo-invoice.png')

      render(html: html.html_safe) # rubocop:disable Rails/OutputSafety
    end

    private

    def payment_receipt
      @payment_receipt ||= PaymentReceipt.find(params[:id])
    end
  end
end
