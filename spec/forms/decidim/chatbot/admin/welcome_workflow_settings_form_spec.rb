# frozen_string_literal: true

require "spec_helper"

module Decidim::Chatbot::Admin
  describe WelcomeWorkflowSettingsForm do
    subject { form }

    let(:organization) { create(:organization) }

    let(:enabled) { false }
    let(:start_workflow) { "organization_welcome" }
    let(:custom_text) { "Welcome message" }

    let(:params) do
      {
        enabled:,
        start_workflow:,
        custom_text:
      }
    end

    let(:form) do
      described_class.from_params(params).with_context(current_organization: organization)
    end

    describe "validations" do
      it { is_expected.to be_valid }

      context "without custom_text" do
        let(:custom_text) { nil }

        it { is_expected.to be_valid }
      end

      context "with blank custom_text" do
        let(:custom_text) { "" }

        it { is_expected.to be_valid }
      end
    end

    describe "#map_model" do
      let(:setting) do
        create(:chatbot_setting,
               organization:,
               start_workflow: "organization_welcome",
               config: { custom_text: "Hello" })
      end

      let(:form) do
        described_class.from_model(setting).with_context(current_organization: organization)
      end

      it "maps custom_text from config" do
        expect(form.custom_text).to eq("Hello")
      end
    end

    describe "#workflow_config" do
      context "with custom_text present" do
        it "returns hash with custom_text" do
          config = form.workflow_config
          expect(config[:custom_text]).to eq(custom_text)
        end
      end

      context "with blank custom_text" do
        let(:custom_text) { "" }

        it "returns empty hash" do
          expect(form.workflow_config).to eq({})
        end
      end

      context "with nil custom_text" do
        let(:custom_text) { nil }

        it "returns empty hash" do
          expect(form.workflow_config).to eq({})
        end
      end
    end
  end
end
