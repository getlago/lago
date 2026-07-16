# frozen_string_literal: true

require "rails_helper"

RSpec.describe LagoHttpClient::Client do
  subject(:client) { described_class.new(url, **client_options) }

  let(:url) { "http://example.com/api/v1/example" }
  let(:client_options) { {} }

  before { stub_const("#{described_class}::RETRY_BACKOFF_RANGE", 0.0..0.0) }

  describe "#initialize" do
    it "parses the URL into a URI" do
      expect(client.uri).to eq URI("http://example.com/api/v1/example")
    end

    context "with custom open_timeout" do
      let(:client_options) { {open_timeout: 5} }

      it "configures open_timeout on the http client" do
        expect(client.send(:http_client).open_timeout).to eq 5
      end
    end

    context "with custom read_timeout" do
      let(:client_options) { {read_timeout: 10} }

      it "configures read_timeout on the http client" do
        expect(client.send(:http_client).read_timeout).to eq 10
      end
    end

    context "with custom write_timeout" do
      let(:client_options) { {write_timeout: 15} }

      it "configures write_timeout on the http client" do
        expect(client.send(:http_client).write_timeout).to eq 15
      end
    end

    context "with HTTPS URL" do
      let(:url) { "https://example.com/api/v1/example" }

      it "enables SSL" do
        expect(client.send(:http_client).use_ssl?).to be true
      end
    end

    context "with HTTP URL" do
      it "does not enable SSL" do
        expect(client.send(:http_client).use_ssl?).to be false
      end
    end

    context "with retries_on option" do
      let(:client_options) { {retries_on: [Net::OpenTimeout, Net::ReadTimeout]} }

      it "stores the retries_on classes" do
        expect(client.retries_on).to eq [Net::OpenTimeout, Net::ReadTimeout]
      end
    end
  end

  describe "timeouts" do
    context "when open timeout occurs" do
      before do
        stub_request(:post, url).to_raise(Net::OpenTimeout)
      end

      it "raises Net::OpenTimeout" do
        expect { client.post({}, []) }.to raise_error(Net::OpenTimeout)
      end
    end

    context "when read timeout occurs" do
      before do
        stub_request(:post, url).to_raise(Net::ReadTimeout)
      end

      it "raises Net::ReadTimeout" do
        expect { client.post({}, []) }.to raise_error(Net::ReadTimeout)
      end
    end

    context "when write timeout occurs" do
      before do
        stub_request(:post, url).to_raise(Net::WriteTimeout)
      end

      it "raises Net::WriteTimeout" do
        expect { client.post({}, []) }.to raise_error(Net::WriteTimeout)
      end
    end

    context "with retries_on configured for timeouts" do
      let(:client_options) { {retries_on: [Net::OpenTimeout, Net::ReadTimeout]} }

      context "when open timeout occurs and succeeds on retry" do
        before do
          call_count = 0
          stub_request(:post, url).to_return do
            call_count += 1
            raise Net::OpenTimeout if call_count == 1
            {body: '{"retried": true}', status: 200}
          end
        end

        it "retries and returns successful response" do
          expect(client.post({}, [])).to eq({"retried" => true})
        end
      end

      context "when read timeout occurs and succeeds on retry" do
        before do
          call_count = 0
          stub_request(:post, url).to_return do
            call_count += 1
            raise Net::ReadTimeout if call_count == 1
            {body: '{"retried": true}', status: 200}
          end
        end

        it "retries and returns successful response" do
          expect(client.post({}, [])).to eq({"retried" => true})
        end
      end

      context "when write timeout occurs (not in retries_on)" do
        before do
          stub_request(:post, url).to_raise(Net::WriteTimeout)
        end

        it "raises immediately without retry" do
          expect { client.post({}, []) }.to raise_error(Net::WriteTimeout)
        end
      end
    end
  end

  describe "#post" do
    let(:request_body) { {data: "test"} }
    let(:request_headers) { [{"Authorization" => "Bearer token"}, {"X-Custom" => "value"}] }

    context "when response status code is 2xx" do
      let(:response_body) { {"status" => 200, "message" => "Success"}.to_json }

      before do
        stub_request(:post, url)
          .with(
            body: request_body.to_json,
            headers: {"Content-Type" => "application/json", "Authorization" => "Bearer token", "X-Custom" => "value"}
          )
          .to_return(body: response_body, status: 200)
      end

      it "returns parsed JSON response body" do
        response = client.post(request_body, request_headers)

        expect(response).to eq({"status" => 200, "message" => "Success"})
      end
    end

    context "when response body is blank" do
      before do
        stub_request(:post, url).to_return(body: "", status: 200)
      end

      it "returns an empty hash" do
        expect(client.post({}, [])).to eq({})
      end
    end

    context "when response body is nil" do
      before do
        stub_request(:post, url).to_return(body: nil, status: 200)
      end

      it "returns an empty hash" do
        expect(client.post({}, [])).to eq({})
      end
    end

    context "when response is not valid JSON" do
      before do
        stub_request(:post, url).to_return(body: "Accepted", status: 200)
      end

      it "returns the raw response body" do
        expect(client.post({}, [])).to eq("Accepted")
      end
    end

    context "when response status code is NOT 2xx" do
      before do
        stub_request(:post, url).to_return(body: "Error", status: 422)
      end

      it "raises an HttpError" do
        expect { client.post({}, []) }.to raise_error(LagoHttpClient::HttpError) do |error|
          expect(error.error_code).to eq "422"
          expect(error.error_body).to eq "Error"
        end
      end
    end

    context "when path is empty" do
      let(:url) { "http://example.com" }

      before do
        stub_request(:post, "http://example.com/").to_return(body: "{}", status: 200)
      end

      it "makes request to root path" do
        expect(client.post({}, [])).to eq({})
      end
    end

    context "with query params in URL" do
      let(:url) { "http://example.com/api?foo=bar" }

      before do
        stub_request(:post, "http://example.com/api?foo=bar").to_return(body: "{}", status: 200)
      end

      it "preserves query params" do
        expect(client.post({}, [])).to eq({})
      end
    end
  end

  describe "#post_with_response" do
    let(:request_body) { {data: "test"} }
    let(:request_headers) { {"Authorization" => "Bearer token", "X-Custom" => "value"} }

    context "when response is successful" do
      before do
        stub_request(:post, url)
          .with(
            body: request_body.to_json,
            headers: {"Content-Type" => "application/json", "Authorization" => "Bearer token", "X-Custom" => "value"}
          )
          .to_return(body: "OK", status: 201)
      end

      it "returns the raw Net::HTTP response" do
        response = client.post_with_response(request_body, request_headers)

        expect(response).to be_a(Net::HTTPResponse)
        expect(response.code).to eq "201"
        expect(response.body).to eq "OK"
      end
    end

    context "when response status code is NOT 2xx" do
      before do
        stub_request(:post, url).to_return(body: "Error", status: 500)
      end

      it "raises an HttpError" do
        expect { client.post_with_response({}, {}) }.to raise_error(LagoHttpClient::HttpError)
      end
    end
  end

  describe "#put_with_response" do
    let(:request_body) { {data: "updated"} }
    let(:request_headers) { {"Authorization" => "Bearer token"} }

    context "when response is successful" do
      before do
        stub_request(:put, url)
          .with(
            body: request_body.to_json,
            headers: {"Content-Type" => "application/json", "Authorization" => "Bearer token"}
          )
          .to_return(body: "Updated", status: 200)
      end

      it "returns the raw Net::HTTP response" do
        response = client.put_with_response(request_body, request_headers)

        expect(response).to be_a(Net::HTTPResponse)
        expect(response.code).to eq "200"
        expect(response.body).to eq "Updated"
      end
    end

    context "when response status code is NOT 2xx" do
      before do
        stub_request(:put, url).to_return(body: "Error", status: 404)
      end

      it "raises an HttpError" do
        expect { client.put_with_response({}, {}) }.to raise_error(LagoHttpClient::HttpError)
      end
    end
  end

  describe "#post_multipart_file" do
    let(:url) { "http://example.com/upload" }
    let(:file_content) { "file content" }
    let(:temp_file) { Tempfile.new("test") }

    before do
      temp_file.write(file_content)
      temp_file.rewind
    end

    after do
      temp_file.close
      temp_file.unlink
    end

    context "when response is successful" do
      before do
        stub_request(:post, url)
          .with(headers: {"Content-Type" => %r{multipart/form-data}})
          .to_return(body: "Uploaded", status: 200)
      end

      it "returns the raw Net::HTTP response" do
        response = client.post_multipart_file(file: UploadIO.new(temp_file, "text/plain", "test.txt"))

        expect(response).to be_a(Net::HTTPResponse)
        expect(response.code).to eq "200"
      end
    end

    context "when response status code is NOT 2xx" do
      before do
        stub_request(:post, url).to_return(body: "Error", status: 413)
      end

      it "raises an HttpError" do
        expect { client.post_multipart_file({}) }.to raise_error(LagoHttpClient::HttpError)
      end
    end
  end

  describe "#post_url_encoded" do
    let(:params) { {grant_type: "authorization_code", code: "abc123"} }
    let(:request_headers) { {"Authorization" => "Basic xyz"} }

    context "when response is successful" do
      let(:response_body) { {"access_token" => "token123"}.to_json }

      before do
        stub_request(:post, url)
          .with(
            body: "grant_type=authorization_code&code=abc123",
            headers: {"Content-Type" => "application/x-www-form-urlencoded", "Authorization" => "Basic xyz"}
          )
          .to_return(body: response_body, status: 200)
      end

      it "returns parsed JSON response" do
        response = client.post_url_encoded(params, request_headers)

        expect(response).to eq({"access_token" => "token123"})
      end
    end

    context "when response body is blank" do
      before do
        stub_request(:post, url).to_return(body: "", status: 200)
      end

      it "returns an empty hash" do
        expect(client.post_url_encoded({}, {})).to eq({})
      end
    end

    context "when response status code is NOT 2xx" do
      before do
        stub_request(:post, url).to_return(body: "Error", status: 401)
      end

      it "raises an HttpError" do
        expect { client.post_url_encoded({}, {}) }.to raise_error(LagoHttpClient::HttpError)
      end
    end
  end

  describe "#post_with_stream" do
    let(:request_body) { {prompt: "Hello"} }
    let(:request_headers) { {"Authorization" => "Bearer token"} }

    context "when response is successful" do
      let(:sse_response) { "event: message\ndata: {\"text\":\"Hello\"}\n\nevent: message\ndata: {\"text\":\"World\"}\n\n" }

      before do
        stub_request(:post, url)
          .with(body: request_body.to_json, headers: {"Content-Type" => "application/json", "Authorization" => "Bearer token"})
          .to_return(body: sse_response, status: 200)
      end

      it "yields parsed SSE events" do
        events = []
        client.post_with_stream(request_body, request_headers) do |type, data, id, reconnection_time|
          events << {type: type, data: data, id: id, reconnection_time: reconnection_time}
        end

        expect(events.size).to eq 2
        expect(events[0][:type]).to eq "message"
        expect(events[0][:data]).to eq '{"text":"Hello"}'
        expect(events[1][:data]).to eq '{"text":"World"}'
      end
    end

    context "when response status code is NOT 2xx" do
      before do
        stub_request(:post, url).to_return(body: "Error", status: 500)
      end

      it "raises an HttpError" do
        expect { client.post_with_stream({}, {}) { |*| } }.to raise_error(LagoHttpClient::HttpError)
      end
    end
  end

  describe "#get" do
    context "when response is successful" do
      let(:response_body) { {"data" => [1, 2, 3]}.to_json }

      before do
        stub_request(:get, url)
          .with(headers: {"Authorization" => "Bearer token"})
          .to_return(body: response_body, status: 200)
      end

      it "returns parsed JSON response" do
        response = client.get(headers: {"Authorization" => "Bearer token"})

        expect(response).to eq({"data" => [1, 2, 3]})
      end
    end

    context "with query params" do
      let(:url) { "http://example.com/api" }

      before do
        stub_request(:get, "http://example.com/api?page=1&per_page=10")
          .to_return(body: "{}", status: 200)
      end

      it "appends params to the URL" do
        expect(client.get(params: {page: 1, per_page: 10})).to eq({})
      end
    end

    context "with body" do
      context "without content_type" do
        before do
          stub_request(:get, url)
            .with(body: "filter=active")
            .to_return(body: "{}", status: 200)
        end

        it "sends URL-encoded body" do
          expect(client.get(body: {filter: "active"})).to eq({})
        end
      end

      context "with application/json content_type" do
        before do
          stub_request(:get, url)
            .with(
              body: '{"filter":"active"}',
              headers: {"Content-Type" => "application/json"}
            )
            .to_return(body: "{}", status: 200)
        end

        it "sends a JSON-encoded body with application/json content type" do
          expect(client.get(body: {filter: "active"}, content_type: "application/json")).to eq({})
        end
      end
    end

    context "when response body is blank" do
      before do
        stub_request(:get, url).to_return(body: "", status: 200)
      end

      it "returns an empty hash" do
        expect(client.get).to eq({})
      end
    end

    context "when response status code is NOT 2xx" do
      before do
        stub_request(:get, url).to_return(body: "Not Found", status: 404)
      end

      it "raises an HttpError" do
        expect { client.get }.to raise_error(LagoHttpClient::HttpError)
      end
    end
  end

  describe "retry logic" do
    let(:client_options) { {retries_on: [Net::OpenTimeout]} }

    context "when retryable error occurs" do
      before do
        call_count = 0
        stub_request(:post, url).to_return do
          call_count += 1
          if call_count < 3
            raise Net::OpenTimeout
          else
            {body: "{}", status: 200}
          end
        end
      end

      it "retries up to MAX_RETRIES_ATTEMPTS times" do
        expect(client.post({}, [])).to eq({})
      end
    end

    context "when retryable error exceeds max attempts" do
      before do
        stub_request(:post, url).to_raise(Net::OpenTimeout)
      end

      it "re-raises the original error after exhausting retries" do
        expect { client.post({}, []) }.to raise_error(Net::OpenTimeout)
      end
    end

    context "when non-retryable error occurs" do
      before do
        stub_request(:post, url).to_raise(Errno::ECONNREFUSED)
      end

      it "raises the error immediately" do
        expect { client.post({}, []) }.to raise_error(Errno::ECONNREFUSED)
      end
    end

    context "when retries_on is empty" do
      let(:client_options) { {retries_on: []} }

      before do
        stub_request(:post, url).to_raise(Net::OpenTimeout)
      end

      it "raises the error immediately" do
        expect { client.post({}, []) }.to raise_error(Net::OpenTimeout)
      end
    end

    context "with retry_on_transient_errors enabled" do
      let(:client_options) { {retry_on_transient_errors: true} }

      context "when the response is a 500 then succeeds" do
        before do
          call_count = 0
          stub_request(:post, url).to_return do
            call_count += 1
            if call_count == 1
              {body: "transient error", status: 500}
            else
              {body: "{}", status: 200}
            end
          end
        end

        it "retries and returns the parsed body" do
          expect(client.post({}, [])).to eq({})
        end
      end

      context "when the response is a 503 on every call" do
        before do
          stub_request(:post, url).to_return(body: "unavailable", status: 503)
        end

        it "raises an HttpError after exhausting retries" do
          expect { client.post({}, []) }.to raise_error(LagoHttpClient::HttpError) do |error|
            expect(error.error_code).to eq "503"
          end
        end
      end

      context "when a transient exception occurs then succeeds" do
        before do
          call_count = 0
          stub_request(:post, url).to_return do
            call_count += 1
            if call_count == 1
              raise Net::OpenTimeout
            else
              {body: "{}", status: 200}
            end
          end
        end

        it "retries and returns the parsed body" do
          expect(client.post({}, [])).to eq({})
        end
      end

      context "when an SSL error occurs then succeeds" do
        before do
          call_count = 0
          stub_request(:post, url).to_return do
            call_count += 1
            if call_count == 1
              raise OpenSSL::SSL::SSLError
            else
              {body: "{}", status: 200}
            end
          end
        end

        it "retries and returns the parsed body" do
          expect(client.post({}, [])).to eq({})
        end
      end

      context "when the response is a 4xx" do
        it "raises an HttpError without retrying" do
          stub = stub_request(:post, url).to_return(body: "Error", status: 422)

          expect { client.post({}, []) }.to raise_error(LagoHttpClient::HttpError) do |error|
            expect(error.error_code).to eq "422"
          end
          expect(stub).to have_been_requested.once
        end
      end

      context "when a transient exception occurs on every call" do
        let(:call_count) { {value: 0} }

        before do
          counter = call_count
          stub_request(:post, url).to_return do
            counter[:value] += 1
            raise Errno::ECONNRESET
          end
        end

        # Exception-path exhaustion goes through the `is_a?` branch of
        # `transient_exception?`, distinct from the `retries_on.include?` branch.
        it "re-raises the original error after exhausting retries" do
          expect { client.post({}, []) }.to raise_error(Errno::ECONNRESET)
        end

        it "attempts exactly MAX_RETRIES_ATTEMPTS times" do
          expect { client.post({}, []) }.to raise_error(Errno::ECONNRESET)
          expect(call_count[:value]).to eq(described_class::MAX_RETRIES_ATTEMPTS)
        end
      end

      context "when a retryable status is returned on every call" do
        it "attempts exactly MAX_RETRIES_ATTEMPTS times" do
          stub = stub_request(:post, url).to_return(body: "unavailable", status: 503)

          expect { client.post({}, []) }.to raise_error(LagoHttpClient::HttpError)
          expect(stub).to have_been_requested.times(described_class::MAX_RETRIES_ATTEMPTS)
        end
      end

      context "when a non-transient exception occurs" do
        before do
          stub_request(:post, url).to_raise(ArgumentError)
        end

        # ArgumentError is neither in retries_on nor TRANSIENT_ERROR_CLASSES,
        # so it must propagate immediately even with the flag enabled.
        it "raises the error immediately without retrying" do
          expect { client.post({}, []) }.to raise_error(ArgumentError)
        end
      end
    end

    context "with retry_on_transient_errors disabled (default)" do
      let(:client_options) { {} }

      it "raises an HttpError without retrying on a 500" do
        stub = stub_request(:post, url).to_return(body: "Error", status: 500)

        expect { client.post({}, []) }.to raise_error(LagoHttpClient::HttpError)
        expect(stub).to have_been_requested.once
      end
    end
  end

  describe "response success codes" do
    described_class::RESPONSE_SUCCESS_CODES.each do |code|
      context "when response code is #{code}" do
        before do
          stub_request(:post, url).to_return(body: "{}", status: code)
        end

        it "does not raise an error" do
          expect { client.post({}, []) }.not_to raise_error
        end
      end
    end

    [400, 401, 403, 404, 422, 500, 502, 503].each do |code|
      context "when response code is #{code}" do
        before do
          stub_request(:post, url).to_return(body: "Error", status: code)
        end

        it "raises an HttpError" do
          expect { client.post({}, []) }.to raise_error(LagoHttpClient::HttpError) do |error|
            expect(error.error_code).to eq code.to_s
          end
        end
      end
    end
  end
end
