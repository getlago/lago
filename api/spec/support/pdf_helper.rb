# frozen_string_literal: true

module PdfHelper
  # This helper stubs the PDF generation request to return the input HTML as response so that it can be used in the tests.
  def stub_pdf_generation
    stub_request(:post, "#{ENV["LAGO_PDF_URL"]}/forms/chromium/convert/html")
      .to_return do |request|
        env = {
          "CONTENT_TYPE" => request.headers["Content-Type"],
          "CONTENT_LENGTH" => request.headers["Content-Length"],
          "rack.input" => StringIO.new(request.body)
        }
        params = Rack::Multipart.parse_multipart(env)
        html = params["file1"][:tempfile].read
        {body: html, status: 200}
      end
  end
end
