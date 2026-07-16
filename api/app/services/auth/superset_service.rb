# frozen_string_literal: true

module Auth
  class SupersetService < BaseService
    Result = BaseResult[:dashboards]

    def initialize(organization:, user: nil)
      @organization = organization
      @user = user
      @access_token = nil
      @csrf_token = nil
      @http_client = nil

      super()
    end

    def call
      ensure_superset_configured
      return result unless result.success?

      # Step 1: Authenticate and get access token
      auth_result = authenticate_with_api
      return result unless auth_result[:success]

      @access_token = auth_result[:access_token]

      # Step 2: Get CSRF token (authenticated with Bearer token)
      csrf_result = get_csrf_token
      return result unless csrf_result[:success]

      @csrf_token = csrf_result[:csrf_token]

      # Step 3: Fetch all dashboards
      dashboards_result = fetch_dashboards
      return result unless dashboards_result[:success]

      # Step 4: Process each dashboard to ensure embedded config and get guest token
      processed_dashboards = []
      dashboards_result[:dashboards].each do |dashboard|
        embedded_config = ensure_embedded_config(dashboard["id"])
        next unless embedded_config[:success]

        guest_token_result = get_guest_token(dashboard["id"])
        next unless guest_token_result[:success]

        processed_dashboards << {
          id: dashboard["id"].to_s,
          dashboard_title: dashboard["dashboard_title"],
          embedded_id: embedded_config[:uuid],
          guest_token: guest_token_result[:guest_token]
        }
      end

      result.dashboards = processed_dashboards
      result
    rescue URI::InvalidURIError => e
      result.service_failure!(code: "superset_invalid_url", message: "Invalid Superset URL: #{e.message}")
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      result.service_failure!(code: "superset_timeout", message: "Superset request timed out: #{e.message}")
    rescue JSON::ParserError => e
      result.service_failure!(code: "superset_invalid_response", message: "Invalid JSON response from Superset: #{e.message}")
    rescue => e
      result.service_failure!(code: "superset_error", message: "Superset operation failed: #{e.message}")
    end

    private

    attr_reader :organization, :user, :access_token, :csrf_token

    def http_client
      @http_client ||= LagoHttpClient::SessionClient.new(superset_base_url)
    end

    def base_headers(referer_path: "/")
      {
        "Origin" => superset_base_url,
        "Referer" => "#{superset_base_url}#{referer_path}"
      }
    end

    def api_headers(referer_path: "/")
      base_headers(referer_path:).merge("Accept" => "application/json")
    end

    def authenticated_api_headers(referer_path: "/")
      api_headers(referer_path:).merge(
        "Authorization" => "Bearer #{access_token}",
        "X-CSRFToken" => csrf_token
      )
    end

    def authenticated_json_headers(referer_path: "/")
      authenticated_api_headers(referer_path:).merge("Content-Type" => "application/json")
    end

    def authenticate_with_api
      body = {
        username: superset_username,
        password: superset_password,
        provider: "db"
      }

      headers = api_headers(referer_path: "/login/").merge("Content-Type" => "application/json")
      response = http_client.post("/api/v1/security/login", body:, headers:)
      parsed_response = JSON.parse(response.body)
      access_token = parsed_response["access_token"]

      unless access_token
        result.service_failure!(code: "superset_auth_failed", message: "No access token received from Superset")
        return {success: false}
      end

      {success: true, access_token:}
    rescue LagoHttpClient::HttpError => e
      result.service_failure!(code: "superset_auth_failed", message: "Failed to authenticate with Superset: #{e.error_code} #{e.message}")
      {success: false}
    end

    def get_csrf_token
      headers = api_headers.merge("Authorization" => "Bearer #{access_token}")
      response = http_client.get("/api/v1/security/csrf_token/", headers:)
      parsed_response = JSON.parse(response.body)
      csrf_token = parsed_response["result"]

      unless csrf_token
        result.service_failure!(code: "superset_no_csrf_token", message: "No CSRF token received from Superset")
        return {success: false}
      end

      {success: true, csrf_token:}
    rescue LagoHttpClient::HttpError => e
      result.service_failure!(code: "superset_csrf_failed", message: "Failed to get CSRF token: #{e.error_body}")
      {success: false}
    end

    def fetch_dashboards
      response = http_client.get("/api/v1/dashboard/", headers: authenticated_api_headers)
      parsed_response = JSON.parse(response.body)
      dashboards = parsed_response["result"] || []

      {success: true, dashboards:}
    rescue LagoHttpClient::HttpError => e
      result.service_failure!(code: "superset_fetch_dashboards_failed", message: "Failed to fetch dashboards: #{e.error_body}")
      {success: false}
    end

    def get_embedded_config(dashboard_id)
      response = http_client.get("/api/v1/dashboard/#{dashboard_id}/embedded", headers: authenticated_api_headers)
      parsed_response = JSON.parse(response.body)
      uuid = parsed_response["result"]&.[]("uuid")

      return {success: true, uuid:, exists: true} if uuid

      {success: true, exists: false}
    rescue LagoHttpClient::HttpError, JSON::ParserError
      {success: true, exists: false}
    end

    def create_embedded_config(dashboard_id)
      body = {allowed_domains: []}
      response = http_client.post("/api/v1/dashboard/#{dashboard_id}/embedded", body: body, headers: authenticated_json_headers)
      parsed_response = JSON.parse(response.body)
      uuid = parsed_response["result"]&.[]("uuid")

      return {success: false} unless uuid

      {success: true, uuid: uuid}
    rescue LagoHttpClient::HttpError, JSON::ParserError
      {success: false}
    end

    def ensure_embedded_config(dashboard_id)
      embedded_config = get_embedded_config(dashboard_id)
      return {success: false} unless embedded_config[:success]

      return {success: true, uuid: embedded_config[:uuid]} if embedded_config[:exists]

      create_embedded_config(dashboard_id)
    end

    def get_guest_token(dashboard_id)
      body = {
        resources: [{id: dashboard_id.to_s, type: "dashboard"}],
        rls: [
          {
            clause: "organization_id = '#{organization.id}'"
          }
        ],
        user: guest_user_info
      }

      response = http_client.post("/api/v1/security/guest_token/", body:, headers: authenticated_json_headers)
      parsed_response = JSON.parse(response.body)
      guest_token = parsed_response["token"] || parsed_response["result"] || parsed_response["access_token"]

      return {success: false} unless guest_token

      {success: true, guest_token:}
    rescue LagoHttpClient::HttpError, JSON::ParserError
      {success: false}
    end

    def guest_user_info
      user.presence || {
        first_name: organization.name || "Guest",
        last_name: "User",
        username: "guest_#{organization.id}"
      }
    end

    def ensure_superset_configured
      missing_vars = []
      missing_vars << "SUPERSET_URL" if superset_base_url.blank?
      missing_vars << "SUPERSET_USERNAME" if superset_username.blank?
      missing_vars << "SUPERSET_PASSWORD" if superset_password.blank?

      return if missing_vars.empty?

      result.service_failure!(
        code: "superset_missing_configuration",
        message: "Superset configuration is incomplete. Missing: #{missing_vars.join(", ")}"
      )
    end

    def superset_base_url
      ENV["SUPERSET_URL"]
    end

    def superset_username
      ENV["SUPERSET_USERNAME"]
    end

    def superset_password
      ENV["SUPERSET_PASSWORD"]
    end
  end
end
