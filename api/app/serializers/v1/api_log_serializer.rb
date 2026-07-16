# frozen_string_literal: true

module V1
  class ApiLogSerializer < ModelSerializer
    def serialize
      {
        request_id: model.request_id,
        client: model.client,
        http_method: model.http_method,
        http_status: model.http_status,
        request_origin: model.request_origin,
        request_path: model.request_path,
        request_body: model.request_body,
        request_response: model.request_response,
        api_version: model.api_version,
        logged_at: model.logged_at.iso8601,
        created_at: model.created_at.iso8601
      }
    end
  end
end
