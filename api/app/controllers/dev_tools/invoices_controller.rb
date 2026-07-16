# frozen_string_literal: true

module DevTools
  class InvoicesController < ApplicationController
    def show
      service = ::Invoices::GeneratePdfService.new(invoice:)

      # For PDFs we need to use a simple file name and the file is passed to `gotenberg`
      # In order to reuse the exact same template to display in HTML, we replace the image path
      html = service.render_html.gsub('src="lago-logo-invoice.png', 'src="/assets/images/lago-logo-invoice.png')

      render(html: html.html_safe) # rubocop:disable Rails/OutputSafety
    end

    private

    def invoice
      @invoice ||= Invoice.find(params[:id])
    end
  end
end
