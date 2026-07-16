# frozen_string_literal: true

require "rails_helper"

RSpec.describe Metadata::ItemMetadata do
  subject(:item_metadata) { described_class.new(organization:, owner:, value:) }

  let(:organization) { create(:organization) }
  let(:invoice) { create(:invoice, organization:) }
  let(:customer) { invoice.customer }
  let(:owner) { create(:credit_note, invoice:, customer:, organization:) }
  let(:value) { {"key1" => "value1"} }

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:owner) }

  describe "validations" do
    describe "of value not being nil" do
      context "when value is nil" do
        let(:value) { nil }

        it "adds an error" do
          expect(item_metadata).not_to be_valid
          expect(item_metadata.errors[:value]).to be_present
        end
      end

      context "when value is an empty hash" do
        let(:value) { {} }

        it "is valid" do
          expect(item_metadata).to be_valid
        end
      end
    end

    describe "of owner uniqueness" do
      context "when owner is nil" do
        let(:owner) { nil }

        it "adds an error" do
          expect(item_metadata).not_to be_valid
          expect(item_metadata.errors[:owner]).to be_present
        end
      end

      context "when owner is already taken" do
        before { described_class.create!(organization:, owner:, value:) }

        it "is valid at app level but raises database error on save" do
          expect(item_metadata).to be_valid
          expect { item_metadata.save! }.to raise_error(ActiveRecord::RecordNotUnique)
        end
      end
    end

    describe "of value correctness" do
      context "when value is valid" do
        let(:value) { {"key1" => "value1", "key2" => "value2"} }

        it { expect(item_metadata).to be_valid }
      end

      context "when value is not a Hash" do
        let(:value) { "not a hash" }

        it "adds an error" do
          expect(item_metadata).not_to be_valid
          expect(item_metadata.errors[:value]).to include("must be a Hash")
        end
      end

      context "when value has more than 50 keys" do
        let(:value) { 51.times.to_h { |i| ["key#{i}", "value#{i}"] } }

        it "adds an error" do
          expect(item_metadata).not_to be_valid
          expect(item_metadata.errors[:value]).to include("cannot have more than 50 keys")
        end
      end

      context "when key is empty" do
        let(:value) { {"" => "value"} }

        it "is valid" do
          expect(item_metadata).to be_valid
        end
      end

      context "when key length is more than 100" do
        let(:value) { {("a" * 101) => "value"} }

        it "adds an error" do
          key = "a" * 101
          expect(item_metadata).not_to be_valid
          expect(item_metadata.errors[:value]).to include("key '#{key}' must be a String up to 100 characters")
        end
      end

      context "when value is nil" do
        let(:value) { {"foo" => nil} }

        it "is valid" do
          expect(item_metadata).to be_valid
        end
      end

      context "when value is not a String" do
        let(:value) { {"foo" => 123} }

        it "adds an error" do
          expect(item_metadata).not_to be_valid
          expect(item_metadata.errors[:value].join).to include("value for key 'foo' must be empty or a String up to 255 characters")
        end
      end

      context "when value length is less than 1" do
        let(:value) { {"foo" => ""} }

        it "is valid" do
          expect(item_metadata).to be_valid
        end
      end

      context "when value length is more than 255" do
        let(:value) { {"foo" => "a" * 256} }

        it "adds an error" do
          expect(item_metadata).not_to be_valid
          expect(item_metadata.errors[:value].join).to include("value for key 'foo' must be empty or a String up to 255 characters")
        end
      end

      context "when value is a non-string leaf for every owner type" do
        let(:owner) do
          case owner_type
          when :credit_note then create(:credit_note, invoice:, customer:, organization:)
          when :wallet then create(:wallet, organization:)
          when :plan then create(:plan, organization:)
          end
        end

        [:credit_note, :wallet, :plan].each do |type|
          context "when owner is a #{type}" do
            let(:owner_type) { type }

            context "when value is false" do
              let(:value) { {"foo" => false} }

              it "adds an error" do
                expect(item_metadata).not_to be_valid
                expect(item_metadata.errors[:value].join).to include("value for key 'foo' must be empty or a String up to 255 characters")
              end
            end

            context "when value is an empty array" do
              let(:value) { {"foo" => []} }

              it "adds an error" do
                expect(item_metadata).not_to be_valid
                expect(item_metadata.errors[:value].join).to include("value for key 'foo' must be empty or a String up to 255 characters")
              end
            end

            context "when value is an empty hash" do
              let(:value) { {"foo" => {}} }

              it "adds an error" do
                expect(item_metadata).not_to be_valid
                expect(item_metadata.errors[:value].join).to include("value for key 'foo' must be empty or a String up to 255 characters")
              end
            end
          end
        end
      end
    end
  end

  describe "database constraints" do
    describe "NOT NULL constraints" do
      it "enforces organization_id presence" do
        item_metadata.organization_id = nil
        expect { item_metadata.save!(validate: false) }
          .to raise_error(ActiveRecord::NotNullViolation)
      end

      it "enforces owner_type presence" do
        item_metadata.owner_type = nil
        expect { item_metadata.save!(validate: false) }
          .to raise_error(ActiveRecord::NotNullViolation)
      end

      it "enforces owner_id presence" do
        item_metadata.owner_id = nil
        expect { item_metadata.save!(validate: false) }
          .to raise_error(ActiveRecord::NotNullViolation)
      end

      it "enforces value presence" do
        item_metadata.value = nil
        expect { item_metadata.save!(validate: false) }
          .to raise_error(ActiveRecord::NotNullViolation)
      end
    end

    describe "uniqueness constraint on owner" do
      it "prevents duplicate owner_type and owner_id combination" do
        described_class.create!(organization:, owner:, value:)

        new_item = described_class.new(organization:, owner:, value: {"key2" => "value2"})
        expect { new_item.save!(validate: false) }
          .to raise_error(ActiveRecord::RecordNotUnique)
      end
    end

    describe "value must be JSON object constraint" do
      it "prevents non-object JSON values" do
        expect do
          described_class.connection.execute(<<~SQL.squish)
            INSERT INTO item_metadata (
              id, organization_id, owner_type, owner_id, value, created_at, updated_at
            ) VALUES (
              '#{SecureRandom.uuid}',
              '#{organization.id}',
              '#{owner.class.name}',
              '#{owner.id}',
              '[]',
              NOW(),
              NOW()
            )
          SQL
        end.to raise_error(ActiveRecord::StatementInvalid)
      end
    end
  end
end
