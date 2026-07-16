# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:each, type: :admin) do
    allow(Google::Auth::IDTokens)
      .to receive(:verify_oidc)
      .and_return({email: "test@getlago.com"})
  end
end

module AdminHelper
  def admin_put(path, params = {}, headers = {})
    apply_headers(headers)
    put(path, params: params.to_json, headers:)
  end

  def admin_post(path, params = {}, headers = {})
    apply_headers(headers)
    post(path, params: params.to_json, headers:)
  end

  def admin_post_without_bearer(path, params = {}, headers = {})
    apply_headers(headers)
    headers.delete("Authorization")
    post(path, params: params.to_json, headers:)
  end

  def json
    return response.body unless response.media_type.include?("json")

    JSON.parse(response.body, symbolize_names: true)
  end

  private

  def apply_headers(headers)
    headers["Content-Type"] = "application/json"
    headers["Accept"] = "application/json"
    headers["Authorization"] = "Bearer 123456"
  end
end
