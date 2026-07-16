# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::PaymentProvidersResolver do
  let(:required_permission) { "customers:view" }
  let(:query) do
    <<~GQL
      query {
        paymentProviders(limit: 5) {
          collection {
            ... on AdyenProvider {
              id
              code
              __typename
            }
            ... on CashfreeProvider {
              id
              code
              __typename
            }
            ... on GocardlessProvider {
              id
              code
              __typename
            }
            ... on StripeProvider {
              id
              code
              __typename
            }
          }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:adyen_provider) { create(:adyen_provider, organization:) }
  let(:cashfree_provider) { create(:cashfree_provider, organization:) }
  let(:gocardless_provider) { create(:gocardless_provider, organization:) }
  let(:stripe_provider) { create(:stripe_provider, organization:) }

  before do
    adyen_provider
    cashfree_provider
    gocardless_provider
    stripe_provider
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", %w[customers:view organization:integrations:view]

  context "when type is present" do
    let(:query) do
      <<~GQL
        query {
          paymentProviders(limit: 5, type: stripe) {
            collection {
              ... on AdyenProvider {
                id
                code
                __typename
              }
              ... on CashfreeProvider {
                id
                code
                __typename
              }
              ... on GocardlessProvider {
                id
                code
                __typename
              }
              ... on StripeProvider {
                id
                code
                __typename
              }
            }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    it "returns a list of payment providers" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      payment_providers_response = result["data"]["paymentProviders"]

      expect(payment_providers_response["collection"].count).to eq(1)
      expect(payment_providers_response["collection"].first["id"]).to eq(stripe_provider.id)

      expect(payment_providers_response["metadata"]["currentPage"]).to eq(1)
      expect(payment_providers_response["metadata"]["totalCount"]).to eq(1)
    end
  end

  context "when type is not present" do
    let(:query) do
      <<~GQL
        query {
          paymentProviders(limit: 5) {
            collection {
              ... on AdyenProvider {
                id
                code
                __typename
              }
              ... on CashfreeProvider {
                id
                code
                __typename
              }
              ... on GocardlessProvider {
                id
                code
                __typename
              }
              ... on StripeProvider {
                id
                code
                __typename
              }
            }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    it "returns a list of all payment providers" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      payment_providers_response = result["data"]["paymentProviders"]

      adyen_provider_result = payment_providers_response["collection"].find do |record|
        record["__typename"] == "AdyenProvider"
      end
      cashfree_provider_result = payment_providers_response["collection"].find do |record|
        record["__typename"] == "CashfreeProvider"
      end
      gocardless_provider_result = payment_providers_response["collection"].find do |record|
        record["__typename"] == "GocardlessProvider"
      end
      stripe_provider_result = payment_providers_response["collection"].find do |record|
        record["__typename"] == "StripeProvider"
      end

      expect(payment_providers_response["collection"].count).to eq(4)

      expect(adyen_provider_result["id"]).to eq(adyen_provider.id)
      expect(cashfree_provider_result["id"]).to eq(cashfree_provider.id)
      expect(gocardless_provider_result["id"]).to eq(gocardless_provider.id)
      expect(stripe_provider_result["id"]).to eq(stripe_provider.id)

      expect(payment_providers_response["metadata"]["currentPage"]).to eq(1)
      expect(payment_providers_response["metadata"]["totalCount"]).to eq(4)
    end
  end

  context "when requesting protected fields" do
    let(:query) do
      <<~GQL
        query {
          paymentProviders(limit: 5) {
            collection {
              ... on AdyenProvider {
                livePrefix
              }
              ... on CashfreeProvider {
                clientId
                clientSecret
              }
              ... on GocardlessProvider {
                hasAccessToken
              }
              ... on StripeProvider {
                successRedirectUrl
              }
            }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    context "without organization:integrations:view permission" do
      it "filters out protected fields" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query:
        )

        expect(adyen_provider.live_prefix).to be_a String
        expect(cashfree_provider.client_id).to be_a String
        expect(cashfree_provider.client_secret).to be_a String
        expect(gocardless_provider.access_token).to be_a String
        expect(stripe_provider.success_redirect_url).to be_a String

        payment_providers_response = result["data"]["paymentProviders"]["collection"]
        expect(payment_providers_response.map(&:values)).to contain_exactly([nil], [nil, nil], [nil], [nil])
      end
    end

    context "with permission" do
      it "filters out protected fields" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: ["organization:integrations:view"],
          query:
        )

        payment_providers_response = result["data"]["paymentProviders"]["collection"]
        expect(payment_providers_response.map(&:values)).to contain_exactly(
          [adyen_provider.live_prefix],
          [cashfree_provider.client_id, cashfree_provider.client_secret],
          [true],
          [stripe_provider.success_redirect_url]
        )
      end
    end
  end
end
