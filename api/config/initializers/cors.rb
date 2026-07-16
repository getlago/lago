# frozen_string_literal: true

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before(0, Rack::Cors) do
  allow do
    if ENV.key?("LAGO_FRONT_URL")
      uri = URI(ENV["LAGO_FRONT_URL"])

      frontend_origin = if uri.port.in?([80, 443])
        uri.host
      else
        [uri.host, uri.port].join(":")
      end

      origins frontend_origin
    elsif ENV.key?("LAGO_DOMAIN")
      origins ENV["LAGO_DOMAIN"]
    elsif Rails.env.development?
      origins "app.lago.dev", "api", "lago.ngrok.dev"
    end

    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      expose: ["x-lago-token"]
  end
end
