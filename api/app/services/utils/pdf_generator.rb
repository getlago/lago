# frozen_string_literal: true

module Utils
  class PdfGenerator < BaseService
    include ActiveSupport::NumberHelper

    def initialize(template:, context:)
      @template = template
      @context = context

      super(nil)
    end

    def call
      result.io = StringIO.new(render_pdf)
      result
    end

    def render_html
      Slim::Template.new(template_file).render(context)
    end

    private

    attr_reader :template, :context

    def template_file
      Rails.root.join("app/views/templates/#{template}.slim")
    end

    def pdf_url
      URI.join(ENV["LAGO_PDF_URL"], "/forms/chromium/convert/html").to_s
    end

    def render_pdf
      http_client = LagoHttpClient::Client.new(pdf_url, read_timeout: 300)

      response = http_client.post_multipart_file(
        file1: prepare_http_files(render_html, "text/html", "index.html"),
        file2: prepare_http_files(
          File.read(Rails.root.join("public/assets/images/", SlimHelper::PDF_LOGO_FILENAME)),
          "image/png",
          SlimHelper::PDF_LOGO_FILENAME
        ),
        scale: "1.28",
        marginTop: "0.42",
        marginBottom: "0.42",
        marginLeft: "0.42",
        marginRight: "0.42"
      )

      response.body.force_encoding("UTF-8")
    end

    def prepare_http_files(content, type, name)
      UploadIO.new(StringIO.new(content), type, name)
    end
  end
end
