# frozen_string_literal: true

require "spec_helper"

module Decidim::Chatbot
  describe Setting do
    subject { setting }

    let(:setting) { build(:chatbot_setting) }

    it { is_expected.to be_valid }

    context "without an organization" do
      let(:setting) { build(:chatbot_setting, organization: nil) }

      it { is_expected.not_to be_valid }
    end

    context "without a provider" do
      let(:setting) { build(:chatbot_setting, provider: nil) }

      it { is_expected.not_to be_valid }
    end
  end
end
