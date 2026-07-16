# frozen_string_literal: true

# spec/support/matchers/be_not_found_error_matcher.rb
RSpec::Matchers.define :be_not_found_error do |resource|
  match do |response|
    return false unless response.status == 404

    begin
      json_body = JSON.parse(response.body)
      json_body["status"] == 404 &&
        json_body["error"] == "Not Found" &&
        json_body["code"] == "#{resource}_not_found"
    rescue JSON::ParserError
      false
    end
  end

  failure_message do |response|
    if response.status != 404
      "expected response status to be 404, but was #{response.status}"
    else
      begin
        json_body = JSON.parse(response.body)
        expected_body = {
          "status" => 404,
          "error" => "Not Found",
          "code" => "#{resource}_not_found"
        }
        "expected response body to match #{expected_body.inspect}, but was #{json_body.inspect}"
      rescue JSON::ParserError
        "expected response body to be valid JSON, but was #{response.body.inspect}"
      end
    end
  end

  failure_message_when_negated do |response|
    "expected response not to be a not_found_error for #{resource}, but it was"
  end

  description do
    "be a not found error response for #{resource}"
  end
end
