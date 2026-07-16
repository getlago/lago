# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entitlement::Privilege do
  subject { build(:privilege) }

  it { expect(described_class).to be_soft_deletable }

  describe "associations" do
    it do
      expect(subject).to belong_to(:organization)
      expect(subject).to belong_to(:feature).class_name("Entitlement::Feature")
      expect(subject).to have_many(:values).class_name("Entitlement::EntitlementValue").dependent(:destroy)
      expect(subject).to have_many(:entitlements).class_name("Entitlement::Entitlement").through(:values)
    end
  end

  describe "validations" do
    it do
      expect(subject).to validate_presence_of(:code)
      expect(subject).to validate_length_of(:code).is_at_most(255)
      expect(subject).to validate_length_of(:name).is_at_most(255)
      expect(subject).to validate_presence_of(:value_type)
      expect(subject).to validate_inclusion_of(:value_type).in_array(Entitlement::Privilege::VALUE_TYPES)
    end

    describe "#validate_config" do
      before do
        subject.value_type = "select"
      end

      context "when value_type is select" do
        it "is valid with proper select_options config" do
          subject.config = {"select_options" => ["option1", "option2"]}
          expect(subject).to be_valid
        end

        it "is invalid with empty select_options array" do
          subject.config = {"select_options" => []}
          expect(subject).not_to be_valid
          expect(subject.errors[:config]).to include("invalid_format")
        end

        it "is invalid with missing select_options key" do
          subject.config = {"other_key" => ["option1"]}
          expect(subject).not_to be_valid
          expect(subject.errors[:config]).to include("invalid_format")
        end

        it "is invalid with additional keys alongside select_options" do
          subject.config = {
            "select_options" => ["option1"],
            "extra_key" => "value"
          }
          expect(subject).not_to be_valid
          expect(subject.errors[:config]).to include("invalid_format")
        end

        it "is invalid with select_options as non-array" do
          subject.config = {"select_options" => "not_an_array"}
          expect(subject).not_to be_valid
          expect(subject.errors[:config]).to include("invalid_format")
        end

        it "is invalid with select_options not all strings" do
          subject.config = {"select_options" => ["true", false]}
          expect(subject).not_to be_valid
          expect(subject.errors[:config]).to include("invalid_format")
        end

        it "is invalid with blank config" do
          subject.config = nil
          expect(subject).not_to be_valid
          expect(subject.errors[:config]).to include("invalid_format")
        end
      end

      context "when value_type is not select" do
        %w[integer string boolean].each do |value_type|
          context "when value_type is #{value_type}" do
            before do
              subject.value_type = value_type
            end

            it "is valid with nil config" do
              subject.config = nil
              expect(subject).to be_valid
            end

            it "is valid with empty hash config" do
              subject.config = {}
              expect(subject).to be_valid
            end

            it "is invalid with any config present" do
              subject.config = {"some_key" => "some_value"}
              expect(subject).not_to be_valid
              expect(subject.errors[:config]).to include("invalid_format")
            end

            it "is invalid with select_options config" do
              subject.config = {"select_options" => ["option1"]}
              expect(subject).not_to be_valid
              expect(subject.errors[:config]).to include("invalid_format")
            end
          end
        end
      end
    end
  end

  describe "value types" do
    it "supports integer type" do
      privilege = create(:privilege, :integer_type)
      expect(privilege.value_type).to eq("integer")
    end

    it "supports string type" do
      privilege = create(:privilege, :string_type)
      expect(privilege.value_type).to eq("string")
    end

    it "supports boolean type" do
      privilege = create(:privilege, :boolean_type)
      expect(privilege.value_type).to eq("boolean")
    end

    it "supports select type" do
      privilege = create(:privilege, :select_type)
      expect(privilege.value_type).to eq("select")
      expect(privilege.config).to include("select_options" => ["option1", "option2", "option3"])
    end
  end

  describe "unique code per feature" do
    it "fails if code already exist for the feature, unless it's soft deleted" do
      feature = create(:feature)
      privilege = create(:privilege, feature:, code: "test")
      expect { create(:privilege, feature:, code: "test") }.to raise_error(ActiveRecord::RecordNotUnique)
      privilege.update! deleted_at: Time.current
      expect { create(:privilege, feature:, code: "test") }.not_to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
