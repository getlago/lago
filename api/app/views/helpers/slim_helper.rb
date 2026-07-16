# frozen_string_literal: true

class SlimHelper
  PDF_LOGO_FILENAME = "lago-logo-invoice.png"

  def self.render(path, context, **locals)
    Slim::Template.new do
      File.read(
        Rails.root.join("app/views/#{path}.slim"),
        encoding: "UTF-8"
      )
    end.render(context, **locals)
  end
end
