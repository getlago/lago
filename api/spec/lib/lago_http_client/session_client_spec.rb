# frozen_string_literal: true

require "rails_helper"

RSpec.describe LagoHttpClient::SessionClient do
  subject(:client) { described_class.new(base_url) }

  let(:base_url) { "http://example.com" }

  describe "#initialize" do
    it "sets default timeouts" do
      expect(client.cookies).to eq([])
    end

    it "can override timeouts" do
      client = described_class.new(base_url, read_timeout: 10, open_timeout: 5)
      expect(client.send(:read_timeout)).to eq(10)
      expect(client.send(:open_timeout)).to eq(5)
    end
  end

  describe "#get" do
    let(:path) { "/api/v1/resource" }
    let(:response_body) { {"status" => "ok", "data" => "test"}.to_json }

    context "when request is successful" do
      before do
        stub_request(:get, "#{base_url}#{path}")
          .to_return(status: 200, body: response_body, headers: {"Content-Type" => "application/json"})
      end

      it "returns the response" do
        response = client.get(path)
        expect(response.body).to eq(response_body)
      end

      it "includes custom headers" do
        stub_request(:get, "#{base_url}#{path}")
          .with(headers: {"Authorization" => "Bearer token"})
          .to_return(status: 200, body: response_body)

        client.get(path, headers: {"Authorization" => "Bearer token"})
      end
    end

    context "when response includes cookies" do
      before do
        stub_request(:get, "#{base_url}#{path}")
          .to_return(
            status: 200,
            body: response_body,
            headers: {"Set-Cookie" => "session_id=abc123; Path=/; HttpOnly"}
          )
      end

      it "stores cookies" do
        client.get(path)
        expect(client.cookies).to eq(["session_id=abc123"])
      end
    end

    context "when response is not successful" do
      before do
        stub_request(:get, "#{base_url}#{path}")
          .to_return(status: 404, body: "Not Found")
      end

      it "raises an HttpError" do
        expect { client.get(path) }.to raise_error(LagoHttpClient::HttpError)
      end
    end

    context "when response is a redirection" do
      before do
        stub_request(:get, "#{base_url}#{path}")
          .to_return(status: 302, body: "", headers: {"Location" => "/new-location"})
      end

      it "does not raise an error" do
        expect { client.get(path) }.not_to raise_error
      end
    end
  end

  describe "#post" do
    let(:path) { "/api/v1/resource" }
    let(:response_body) { {"status" => "created"}.to_json }

    context "when request is successful with JSON body" do
      let(:body) { {name: "test", value: 123} }

      before do
        stub_request(:post, "#{base_url}#{path}")
          .with(
            body: body.to_json,
            headers: {"Content-Type" => "application/json"}
          )
          .to_return(status: 201, body: response_body)
      end

      it "returns the response" do
        response = client.post(path, body: body, headers: {"Content-Type" => "application/json"})
        expect(response.body).to eq(response_body)
      end
    end

    context "when request is successful with form-encoded body" do
      let(:body) { {username: "user", password: "pass"} }

      before do
        stub_request(:post, "#{base_url}#{path}")
          .with(
            body: URI.encode_www_form(body),
            headers: {"Content-Type" => "application/x-www-form-urlencoded"}
          )
          .to_return(status: 200, body: response_body)
      end

      it "returns the response" do
        response = client.post(
          path,
          body: body,
          headers: {"Content-Type" => "application/x-www-form-urlencoded"}
        )
        expect(response.body).to eq(response_body)
      end
    end

    context "when response includes cookies" do
      let(:body) { {data: "test"} }

      before do
        stub_request(:post, "#{base_url}#{path}")
          .to_return(
            status: 200,
            body: response_body,
            headers: {"Set-Cookie" => "auth_token=xyz789; Path=/; Secure"}
          )
      end

      it "stores cookies" do
        client.post(path, body: body, headers: {"Content-Type" => "application/json"})
        expect(client.cookies).to eq(["auth_token=xyz789"])
      end
    end

    context "when response is not successful" do
      let(:body) { {data: "test"} }

      before do
        stub_request(:post, "#{base_url}#{path}")
          .to_return(status: 422, body: "Validation Error")
      end

      it "raises an HttpError" do
        expect do
          client.post(path, body: body, headers: {"Content-Type" => "application/json"})
        end.to raise_error(LagoHttpClient::HttpError)
      end
    end
  end

  describe "cookie management" do
    let(:path) { "/api/v1/resource" }

    context "when multiple cookies are set" do
      before do
        stub_request(:get, "#{base_url}/step1")
          .to_return(
            status: 200,
            body: "{}",
            headers: {
              "Set-Cookie" => [
                "session_id=abc123; Path=/; HttpOnly",
                "user_pref=dark_mode; Path=/"
              ]
            }
          )
      end

      it "stores all cookies" do
        client.get("/step1")
        expect(client.cookies).to contain_exactly("session_id=abc123", "user_pref=dark_mode")
      end
    end

    context "when a cookie is updated" do
      before do
        stub_request(:get, "#{base_url}/step1")
          .to_return(
            status: 200,
            body: "{}",
            headers: {"Set-Cookie" => "session_id=abc123; Path=/"}
          )

        stub_request(:get, "#{base_url}/step2")
          .to_return(
            status: 200,
            body: "{}",
            headers: {"Set-Cookie" => "session_id=xyz789; Path=/"}
          )
      end

      it "replaces the old cookie" do
        client.get("/step1")
        expect(client.cookies).to eq(["session_id=abc123"])

        client.get("/step2")
        expect(client.cookies).to eq(["session_id=xyz789"])
      end
    end

    context "when cookies are sent with requests" do
      before do
        stub_request(:get, "#{base_url}/login")
          .to_return(
            status: 200,
            body: "{}",
            headers: {"Set-Cookie" => "session_id=abc123; Path=/"}
          )

        stub_request(:get, "#{base_url}/protected")
          .with(headers: {"Cookie" => "session_id=abc123"})
          .to_return(status: 200, body: "{}")
      end

      it "includes cookies in subsequent requests" do
        client.get("/login")
        client.get("/protected")

        expect(WebMock).to have_requested(:get, "#{base_url}/protected")
          .with(headers: {"Cookie" => "session_id=abc123"})
      end
    end
  end

  describe "#clear_cookies" do
    before do
      stub_request(:get, "#{base_url}/login")
        .to_return(
          status: 200,
          body: "{}",
          headers: {"Set-Cookie" => "session_id=abc123; Path=/"}
        )
    end

    it "clears all stored cookies" do
      client.get("/login")
      expect(client.cookies).not_to be_empty

      client.clear_cookies
      expect(client.cookies).to be_empty
    end
  end

  describe "retry logic" do
    let(:path) { "/api/v1/resource" }

    context "when request times out" do
      before do
        stub_request(:get, "#{base_url}#{path}")
          .to_timeout
          .then.to_return(status: 200, body: "{}")
      end

      it "retries the request" do
        response = client.get(path)
        expect(response.code).to eq("200")
      end
    end

    context "when request fails multiple times" do
      before do
        stub_request(:get, "#{base_url}#{path}")
          .to_timeout
          .times(3)
      end

      it "raises an error after max retries" do
        expect { client.get(path) }.to raise_error(Net::OpenTimeout)
      end
    end
  end
end
