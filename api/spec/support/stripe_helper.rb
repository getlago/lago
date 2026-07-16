# frozen_string_literal: true

#
# Helper to retrieve and modify stripe fixtures.
# You can pass a block to modify the response.
#
# Example when retrieving customer via the API
#
#         stub_request(:get, %r{/v1/customers/#{provider_customer_id}$}).and_return(
#           status: 200, body: get_stripe_fixtures("customer_retrieve_response.json")
#         )
#
# Example when modifying the response. Keep the change minimal,
# we want the fixtures to be as close as possible to real response
#
#         stub_request(:get, %r{/v1/customers/#{provider_customer_id}$}).and_return(
#           status: 200, body: get_stripe_fixtures("customer_retrieve_response.json") do |res|
#             res["metadata"]["lago_customer_id"] = customer.id
#           end
#         )
module StripeHelper
  def get_stripe_fixtures(file, version: ENV["STRIPE_API_VERSION"])
    full_name = "spec/fixtures/stripe/#{version}/#{file}"
    json = File.read(Rails.root.join(full_name))
    return json unless block_given?
    h = JSON.parse(json).with_indifferent_access
    yield(h)
    h.to_json
  rescue Errno::ENOENT => e
    pps "Fixture not found: #{full_name}"
    raise e
  end
end
