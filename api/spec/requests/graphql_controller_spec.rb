# frozen_string_literal: true

require "rails_helper"

RSpec.describe GraphqlController do
  describe "POST /graphql" do
    before do
      allow(CurrentContext).to receive(:source=)
      allow(CurrentContext).to receive(:api_key_id=)
    end

    context "when logging in" do
      let(:membership) { create(:membership) }
      let(:user) { membership.user }

      let(:mutation) do
        <<~GQL
          mutation($input: LoginUserInput!) {
            loginUser(input: $input) {
              token
              user {
                id
                organizations { id name }
              }
            }
          }
        GQL
      end

      before do
        post "/graphql",
          params: {
            query: mutation,
            variables: {
              input: {
                email: user.email,
                password: "ILoveLago"
              }
            }
          }
      end

      it "returns GraphQL response" do
        expect(response.status).to be(200)
        expect(CurrentContext).to have_received(:source=).with("graphql")
        expect(CurrentContext).to have_received(:api_key_id=).with(nil)

        json = JSON.parse(response.body)
        expect(json["data"]["loginUser"]["token"]).to be_present
        expect(json["data"]["loginUser"]["user"]["id"]).to eq(user.id)
        expect(json["data"]["loginUser"]["user"]["organizations"].first["id"]).to eq(membership.organization_id)
      end

      context "when membership is revoked" do
        let(:membership) { create(:membership, :revoked) }

        it "returns an error" do
          expect(response.status).to be(200)

          json = JSON.parse(response.body)
          error = json["errors"].first
          expect(error["extensions"]["code"]).to eq("unprocessable_entity")
          expect(error.dig("extensions", "details", "base")).to eq ["incorrect_login_or_password"]
          expect(error["extensions"]["status"]).to eq(422)
        end
      end
    end

    context "with JWT token" do
      let(:user) { create(:user) }
      let(:query) do
        <<~GRAPHQL
          query {
            currentUser {
              id
              premium
              memberships {
                status
                organization {
                  id
                }
              }
            }
          }
        GRAPHQL
      end

      let(:token) do
        Auth::TokenService.encode(user:)
      end

      it "retrieves the current user" do
        post "/graphql",
          headers: {
            "Authorization" => "Bearer #{token}"
          },
          params: {
            query:
          }

        expect(response.status).to be(200)
        expect(json[:data][:currentUser][:id]).to eq user.id
        expect(json[:data][:currentUser][:memberships]).to be_empty
      end

      context "when organization id header is set" do
        context "when user is not part of organization" do
          it "returns no membership" do
            post "/graphql",
              headers: {
                "Authorization" => "Bearer #{token}",
                "x-lago-organization" => SecureRandom.uuid
              },
              params: {
                query:
              }

            expect(json[:data][:currentUser][:memberships]).to be_empty
          end
        end

        context "when user is part of organization" do
          let(:admin_role) { create(:role, :admin) }
          let(:membership) { create(:membership, user:) }
          let(:organization) { membership.organization }

          before { create(:membership_role, membership:, role: admin_role) }

          it "returns the membership" do
            post "/graphql",
              headers: {
                "Authorization" => "Bearer #{token}",
                "x-lago-organization" => organization.id
              },
              params: {
                query:
              }

            expect(json[:data][:currentUser][:memberships].sole[:organization][:id]).to eq organization.id
          end
        end

        context "when membership is revoked" do
          let(:membership) { create(:membership, :revoked, user:) }
          let(:organization) { membership.organization }

          it "returns the membership" do
            post "/graphql",
              headers: {
                "Authorization" => "Bearer #{token}",
                "x-lago-organization" => organization.id
              },
              params: {
                query:
              }

            expect(json[:data][:currentUser][:memberships]).to be_empty
          end
        end
      end

      context "when token is near expiration" do
        it "renews the token" do
          post(
            "/graphql",
            headers: {
              "Authorization" => "Bearer #{JWT.encode({sub: user.id, exp: 30.minutes.from_now.to_i}, ENV["SECRET_KEY_BASE"], "HS256")}"
            },
            params: {
              query:
            }
          )

          expect(response.status).to be(200)
          expect(response.headers["x-lago-token"]).to be_present
        end
      end
    end

    context "with customer portal token" do
      let(:customer) { create(:customer) }
      let(:query) do
        <<~GQL
          query {
            customerPortalInvoices(limit: 5) {
              collection { id }
              metadata { currentPage, totalCount }
            }
          }
        GQL
      end
      let(:token) do
        ActiveSupport::MessageVerifier.new(ENV["SECRET_KEY_BASE"]).generate(customer.id, expires_in: 12.hours)
      end

      it "retrieves the correct end user and returns success status code" do
        post(
          "/graphql",
          headers: {
            "customer-portal-token" => token
          },
          params: {
            query:
          }
        )

        expect(response.status).to be(200)
      end
    end

    context "with query length validation" do
      let(:user) { create(:user) }
      let(:token) do
        Auth::TokenService.encode(user:)
      end

      it "rejects queries that exceed maximum length" do
        long_query = "query { " + "a" * (GraphqlController::MAX_QUERY_LENGTH + 1) + " }"

        post "/graphql",
          headers: {
            "Authorization" => "Bearer #{token}"
          },
          params: {
            query: long_query
          }

        expect(response.status).to be(200)

        json = JSON.parse(response.body)
        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to include("Max query length is 15000")
        expect(json["errors"].first["extensions"]["code"]).to eq("query_is_too_large")
        expect(json["errors"].first["extensions"]["status"]).to eq(413)
      end

      it "accepts queries within maximum length" do
        query = <<~GRAPHQL
          query {
            currentUser {
              id
              premium
              memberships {
                status
                organization {
                  id
                }
              }
            }
          }
        GRAPHQL

        post "/graphql",
          headers: {
            "Authorization" => "Bearer #{token}"
          },
          params: {
            query:
          }

        expect(response.status).to be(200)

        expect(json["errors"]).not_to be_present
      end
    end
  end
end
