# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Contacts::Payloads::Netsuite do
  let(:integration) { integration_customer.integration }
  let(:integration_customer) { FactoryBot.create(:netsuite_customer, customer:) }
  let(:customer) { create(:customer, email:, phone:) }
  let(:subsidiary_id) { Faker::Number.number(digits: 2) }
  let(:payload) { described_class.new(integration:, customer:, integration_customer:, subsidiary_id:) }
  let(:customer_link) { payload.__send__(:customer_url) }
  let(:email) { "email@test.com,email2@test.com" }
  let(:phone) { nil }

  describe "#create_body" do
    subject(:create_body_call) { payload.create_body }

    let(:payload_body) do
      {
        "type" => "customer",
        "isDynamic" => true,
        "columns" => {
          "companyname" => customer.name,
          "subsidiary" => subsidiary_id,
          "isperson" => "F",
          "custentity_lago_id" => customer.id,
          "custentity_lago_sf_id" => customer.external_salesforce_id,
          "custentity_lago_customer_link" => customer_link,
          "email" => customer.email.to_s.split(",").first&.strip,
          "phone" => customer.phone.to_s.split(",").first&.strip,
          "entityid" => customer.external_id,
          "autoname" => false
        }.merge(
          customer.customer_type_individual? ? {"firstname" => customer.firstname, "lastname" => customer.lastname} : {}
        ),
        "options" => {
          "ignoreMandatoryFields" => false
        },
        "lines" => lines
      }
    end

    context "when legacy script is false" do
      context "when shipping address is present" do
        context "when shipping address is not the same as billing address" do
          let(:customer) { create(:customer, :with_shipping_address, email:, phone:) }

          let(:lines) do
            [
              {
                "lineItems" => [
                  {
                    "defaultshipping" => false,
                    "defaultbilling" => true,
                    "subObjectId" => "addressbookaddress",
                    "subObject" => {
                      "addr1" => customer.address_line1,
                      "addr2" => customer.address_line2,
                      "city" => customer.city,
                      "zip" => customer.zipcode,
                      "state" => customer.state,
                      "country" => customer.country
                    }
                  },
                  {
                    "defaultshipping" => true,
                    "defaultbilling" => false,
                    "subObjectId" => "addressbookaddress",
                    "subObject" => {
                      "addr1" => customer.shipping_address_line1,
                      "addr2" => customer.shipping_address_line2,
                      "city" => customer.shipping_city,
                      "zip" => customer.shipping_zipcode,
                      "state" => customer.shipping_state,
                      "country" => customer.shipping_country
                    }
                  }
                ],
                "sublistId" => "addressbook"
              }
            ]
          end

          it "returns the payload body" do
            expect(subject).to eq payload_body
          end
        end

        context "when shipping address is the same as billing address" do
          let(:customer) { create(:customer, :with_same_billing_and_shipping_address, email:, phone:) }

          let(:lines) do
            [
              {
                "lineItems" => [
                  {
                    "defaultshipping" => true,
                    "defaultbilling" => true,
                    "subObjectId" => "addressbookaddress",
                    "subObject" => {
                      "addr1" => customer.address_line1,
                      "addr2" => customer.address_line2,
                      "city" => customer.city,
                      "zip" => customer.zipcode,
                      "state" => customer.state,
                      "country" => customer.country
                    }
                  }
                ],
                "sublistId" => "addressbook"
              }
            ]
          end

          it "returns the payload body" do
            expect(subject).to eq payload_body
          end
        end
      end

      context "when shipping address is not present" do
        let(:lines) do
          [
            {
              "lineItems" => [
                {
                  "defaultshipping" => true,
                  "defaultbilling" => true,
                  "subObjectId" => "addressbookaddress",
                  "subObject" => {
                    "addr1" => customer.address_line1,
                    "addr2" => customer.address_line2,
                    "city" => customer.city,
                    "zip" => customer.zipcode,
                    "state" => customer.state,
                    "country" => customer.country
                  }
                }
              ],
              "sublistId" => "addressbook"
            }
          ]
        end

        context "when billing address is present" do
          let(:customer) { create(:customer, email:, phone:, state: nil) }

          it "returns the payload body" do
            expect(subject).to eq payload_body
          end

          context "when city name is too long" do
            let(:customer) { create(:customer, email:, phone:, state: nil, city: "Lorem ipsum dolor sit amet, consectetur adipiscing elit") }

            it "returns the payload body with truncated city name" do
              expect(subject["lines"].first["lineItems"].first["subObject"]["city"]).to eq("Lorem ipsum dolor sit amet, consectetur adipiscing")
            end
          end
        end

        context "when billing address is not present" do
          let(:customer) do
            create(
              :customer,
              email:,
              phone:,
              address_line1: nil,
              address_line2: nil,
              city: nil,
              zipcode: nil,
              state: nil,
              country: nil
            )
          end

          it "returns the payload body without lines" do
            expect(subject).to eq payload_body.except("lines")
          end
        end
      end
    end

    context "when legacy script is true" do
      before { integration.legacy_script = true }

      context "when shipping address is present" do
        context "when shipping address is not the same as billing address" do
          let(:customer) { create(:customer, :with_shipping_address, email:, phone:) }

          let(:lines) do
            [
              {
                "lineItems" => [
                  {
                    "defaultshipping" => false,
                    "defaultbilling" => true,
                    "subObjectId" => "addressbookaddress",
                    "subObject" => {
                      "addr1" => customer.address_line1,
                      "addr2" => customer.address_line2,
                      "city" => customer.city,
                      "zip" => customer.zipcode,
                      "state" => customer.state,
                      "country" => customer.country
                    }
                  },
                  {
                    "defaultshipping" => true,
                    "defaultbilling" => false,
                    "subObjectId" => "addressbookaddress",
                    "subObject" => {
                      "addr1" => customer.shipping_address_line1,
                      "addr2" => customer.shipping_address_line2,
                      "city" => customer.shipping_city,
                      "zip" => customer.shipping_zipcode,
                      "state" => customer.shipping_state,
                      "country" => customer.shipping_country
                    }
                  }
                ],
                "sublistId" => "addressbook"
              }
            ]
          end

          it "returns the payload body without lines" do
            expect(subject).to eq payload_body.except("lines")
          end
        end

        context "when shipping address is the same as billing address" do
          let(:customer) { create(:customer, :with_same_billing_and_shipping_address, email:, phone:) }

          let(:lines) do
            [
              {
                "lineItems" => [
                  {
                    "defaultshipping" => true,
                    "defaultbilling" => true,
                    "subObjectId" => "addressbookaddress",
                    "subObject" => {
                      "addr1" => customer.address_line1,
                      "addr2" => customer.address_line2,
                      "city" => customer.city,
                      "zip" => customer.zipcode,
                      "state" => customer.state,
                      "country" => customer.country
                    }
                  }
                ],
                "sublistId" => "addressbook"
              }
            ]
          end

          it "returns the payload body without lines" do
            expect(subject).to eq payload_body.except("lines")
          end
        end
      end

      context "when shipping address is not present" do
        let(:lines) do
          [
            {
              "lineItems" => [
                {
                  "defaultshipping" => true,
                  "defaultbilling" => true,
                  "subObjectId" => "addressbookaddress",
                  "subObject" => {
                    "addr1" => customer.address_line1,
                    "addr2" => customer.address_line2,
                    "city" => customer.city,
                    "zip" => customer.zipcode,
                    "state" => customer.state,
                    "country" => customer.country
                  }
                }
              ],
              "sublistId" => "addressbook"
            }
          ]
        end

        context "when billing address is present" do
          let(:customer) { create(:customer, email:, phone:) }

          it "returns the payload body without lines" do
            expect(subject).to eq payload_body.except("lines")
          end
        end

        context "when billing address is not present" do
          let(:customer) do
            create(
              :customer,
              email:,
              phone:,
              address_line1: nil,
              address_line2: nil,
              city: nil,
              zipcode: nil,
              state: nil,
              country: nil
            )
          end

          it "returns the payload body without lines" do
            expect(subject).to eq payload_body.except("lines")
          end
        end
      end
    end
  end

  describe "#update_body" do
    subject(:update_body_call) { payload.update_body }

    let(:customer) { create(:customer, customer_type:) }
    let(:isperson) { payload.__send__(:isperson) }

    let(:payload_body) do
      {
        "type" => "customer",
        "recordId" => integration_customer.external_customer_id,
        "columns" => {
          "isperson" => isperson,
          "subsidiary" => integration_customer.subsidiary_id,
          "custentity_lago_sf_id" => customer.external_salesforce_id,
          "custentity_lago_customer_link" => customer_link,
          "email" => customer.email.to_s.split(",").first&.strip,
          "phone" => customer.phone.to_s.split(",").first&.strip,
          "entityid" => customer.external_id,
          "autoname" => false
        }.merge(names),
        "options" => {
          "isDynamic" => false
        }
      }
    end

    context "when customer is an individual" do
      let(:customer_type) { :individual }

      let(:names) do
        {
          "companyname" => customer.name,
          "firstname" => customer.firstname,
          "lastname" => customer.lastname
        }
      end

      it "returns the payload body" do
        expect(subject).to eq payload_body
      end
    end

    context "when customer is not an individual" do
      let(:customer_type) { [nil, :company].sample }

      let(:names) do
        {"companyname" => customer.name}
      end

      it "returns the payload body" do
        expect(subject).to eq payload_body
      end
    end
  end

  describe "#email" do
    subject(:email_call) { payload.__send__(:email) }

    let(:customer) { create(:customer, email:) }

    context "when email is nil" do
      let(:email) { nil }

      it "returns nil" do
        expect(subject).to be(nil)
      end
    end

    context "when email is an empty string" do
      let(:email) { "" }

      it "returns nil" do
        expect(subject).to be(nil)
      end
    end

    context "when email contains one email" do
      let(:email) { Faker::Internet.email }

      it "returns email" do
        expect(subject).to eq(email)
      end
    end

    context "when email contains comma-separated email addresses" do
      let(:email) { "#{email1},#{email2}" }
      let(:email1) { Faker::Internet.email }
      let(:email2) { Faker::Internet.email }

      it "returns first email address" do
        expect(subject).to eq(email1)
      end
    end
  end

  describe "#names" do
    subject(:names_call) { payload.__send__(:names) }

    let(:customer) { create(:customer, customer_type:, name:) }

    context "when customer type is nil" do
      let(:customer_type) { nil }
      let(:name) { Faker::TvShows::SiliconValley.character }
      let(:names) { {"companyname" => customer.name} }

      it "returns the result hash" do
        expect(subject).to eq(names)
      end
    end

    context "when customer type is company" do
      let(:customer_type) { :company }
      let(:name) { Faker::TvShows::SiliconValley.character }

      let(:names) { {"companyname" => customer.name} }

      it "returns the result hash" do
        expect(subject).to eq(names)
      end
    end

    context "when customer type is individual" do
      let(:customer_type) { :individual }

      context "when name is present" do
        let(:name) { Faker::TvShows::SiliconValley.character }

        let(:names) do
          {"companyname" => customer.name, "firstname" => customer.firstname, "lastname" => customer.lastname}
        end

        it "returns the result hash" do
          expect(subject).to eq(names)
        end
      end

      context "when name is not present" do
        let(:name) { nil }

        let(:names) do
          {"firstname" => customer.firstname, "lastname" => customer.lastname}
        end

        it "returns the result hash" do
          expect(subject).to eq(names)
        end
      end
    end
  end

  describe "#isperson" do
    subject(:isperson_call) { payload.__send__(:isperson) }

    let(:customer) { create(:customer, customer_type:) }

    context "when customer type is nil" do
      let(:customer_type) { nil }

      it "returns F" do
        expect(subject).to eq("F")
      end
    end

    context "when customer type is company" do
      let(:customer_type) { :company }

      it "returns F" do
        expect(subject).to eq("F")
      end
    end

    context "when customer type is individual" do
      let(:customer_type) { :individual }

      it "returns T" do
        expect(subject).to eq("T")
      end
    end
  end

  describe "#phone" do
    subject { payload.__send__(:phone) }

    let(:customer) { create(:customer, phone:) }

    context "when phone is nil" do
      let(:phone) { nil }

      it "returns nil" do
        expect(subject).to be(nil)
      end
    end

    context "when phone is an empty string" do
      let(:phone) { "" }

      it "returns nil" do
        expect(subject).to be(nil)
      end
    end

    context "when phone contains one phone number" do
      let(:phone) { Faker::PhoneNumber.phone_number }

      it "returns phone" do
        expect(subject).to eq(phone)
      end
    end

    context "when phone contains comma-separated phone numbers" do
      let(:phone) { "#{phone1},#{phone2}" }
      let(:phone1) { Faker::PhoneNumber.phone_number }
      let(:phone2) { Faker::PhoneNumber.phone_number }

      it "returns first phone number" do
        expect(subject).to eq(phone1)
      end
    end
  end
end
