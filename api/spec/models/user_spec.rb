# frozen_string_literal: true

require "rails_helper"

RSpec.describe User do
  subject { described_class.new(email: "gavin@hooli.com", password: "f**k_piedpiper") }

  it_behaves_like "paper_trail traceable"

  describe "associations" do
    it do
      expect(subject).to have_many(:password_resets)
      expect(subject).to have_many(:user_devices)
      expect(subject).to have_many(:memberships)
      expect(subject).to have_many(:organizations).through(:memberships).class_name("Organization")
      expect(subject).to have_many(:active_memberships).class_name("Membership")
      expect(subject).to have_many(:active_organizations).through(:active_memberships).source(:organization)
      expect(subject).to have_many(:quote_owners).dependent(:destroy)
      expect(subject).to have_many(:quotes).through(:quote_owners)
    end
  end

  describe "normalizations" do
    it "sanitizes email on assignment" do
      user = described_class.new(email: " hello@some\u200Bthing\u2013other.com ", password: "password")
      expect(user.email).to eq("hello@something-other.com")
    end
  end

  describe "Validations" do
    it "is valid with valid attributes" do
      expect(subject).to be_valid
    end

    it "is not valid with no email" do
      subject.email = nil
      expect(subject).not_to be_valid
    end

    it "is not valid with no password" do
      subject.password = nil
      expect(subject).not_to be_valid
    end
  end
end
