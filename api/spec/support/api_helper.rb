# frozen_string_literal: true

module ApiHelper
  def get_with_token(organization, path, params = {}, headers = {})
    set_headers(organization, headers)
    get(path, params:, headers:)
  end

  def post_with_token(organization, path, params = {}, headers = {})
    set_headers(organization, headers)
    post(path, params: params.to_json, headers:)
  end

  def put_with_token(organization, path, params = {}, headers = {})
    set_headers(organization, headers)
    put(path, params: params.to_json, headers:)
  end

  def patch_with_token(organization, path, params = {}, headers = {})
    set_headers(organization, headers)
    patch(path, params: params.to_json, headers:)
  end

  def delete_with_token(organization, path, params = {}, headers = {})
    set_headers(organization, headers)
    delete(path, params: params.to_json, headers:)
  end

  def json
    return response.body unless response.media_type.include?("json")
    return {} if response.body.blank? # handle `head(:ok)`

    JSON.parse(response.body, symbolize_names: true)
  end

  private

  def set_headers(organization, headers)
    headers["Content-Type"] = "application/json"
    headers["Accept"] = "application/json"
    headers["Authorization"] = "Bearer #{organization.api_keys.first.value}"
  end
end
