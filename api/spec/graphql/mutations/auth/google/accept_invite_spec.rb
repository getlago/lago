# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Auth::Google::AcceptInvite do
  let(:google_service) { instance_double(Auth::GoogleService) }
  let(:user) { create(:user) }
  let(:invite) { create(:invite) }

  let(:accept_invite_result) do
    result = BaseService::Result.new
    result.user = user
    result.token = "token"
    result
  end

  let(:mutation) do
    <<~GQL
      mutation($input: GoogleAcceptInviteInput!) {
        googleAcceptInvite(input: $input) {
          token
          user {
            id
            email
          }
        }
      }
    GQL
  end

  before do
    allow(Auth::GoogleService).to receive(:new).and_return(google_service)
    allow(google_service).to receive(:accept_invite).and_return(accept_invite_result)
  end

  it "returns token and user" do
    result = execute_graphql(
      query: mutation,
      request: Rack::Request.new(Rack::MockRequest.env_for("http://example.com")),
      variables: {
        input: {
          code: "code",
          inviteToken: invite.token
        }
      }
    )

    response = result["data"]["googleAcceptInvite"]

    expect(response["token"]).to eq("token")
    expect(response["user"]["id"]).to be_present
    expect(response["user"]["email"]).to be_present
  end

  context "when invite email and google email are different" do
    let(:accept_invite_result) do
      result = BaseService::Result.new
      result.single_validation_failure!(error_code: "invite_email_mistmatch")
      result
    end

    it "returns an error" do
      result = execute_graphql(
        query: mutation,
        request: Rack::Request.new(Rack::MockRequest.env_for("http://example.com")),
        variables: {
          input: {
            code: "code",
            inviteToken: invite.token
          }
        }
      )

      response = result["errors"].first["extensions"]

      expect(response["status"]).to eq(422)
      expect(response["details"]["base"]).to include("invite_email_mistmatch")
    end
  end

  context "when invite does not exist" do
    let(:accept_invite_result) do
      result = BaseService::Result.new
      result.not_found_failure!(resource: "invite")
      result
    end

    it "returns an error" do
      result = execute_graphql(
        query: mutation,
        request: Rack::Request.new(Rack::MockRequest.env_for("http://example.com")),
        variables: {
          input: {
            code: "code",
            inviteToken: invite.token
          }
        }
      )

      response = result["errors"].first["extensions"]

      expect(response["status"]).to eq(404)
      expect(response["details"]["invite"]).to include("not_found")
    end
  end
end
