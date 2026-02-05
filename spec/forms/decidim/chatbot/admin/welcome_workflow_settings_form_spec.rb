# frozen_string_literal: true

require "spec_helper"

module Decidim::Chatbot::Admin
  describe WelcomeWorkflowSettingsForm do
    subject { form }

    let(:organization) { create(:organization) }

    let(:enabled) { false }
    let(:start_workflow) { "organization_welcome" }
    let(:delegate_workflow) { "single_participatory_space_workflow" }
    let(:custom_text) { "Welcome message" }

    let(:params) do
      {
        enabled:,
        start_workflow:,
        delegate_workflow:,
        custom_text:
      }
    end

    let(:form) do
      described_class.from_params(params).with_context(current_organization: organization)
    end

    describe "validations" do
      it { is_expected.to be_valid }

      context "without delegate_workflow" do
        let(:delegate_workflow) { nil }

        it { is_expected.to be_valid }
      end

      context "without custom_text" do
        let(:custom_text) { nil }

        it { is_expected.to be_valid }
      end
    end

    describe "#map_model" do
      let(:setting) do
        create(:chatbot_setting,
               organization:,
               start_workflow: "organization_welcome",
               config: { delegate_workflow: "single_participatory_space_workflow", custom_text: "Hello" })
      end

      let(:form) do
        described_class.from_model(setting).with_context(current_organization: organization)
      end

      it "maps delegate_workflow from config" do
        expect(form.delegate_workflow).to eq("single_participatory_space_workflow")
      end

      it "maps custom_text from config" do
        expect(form.custom_text).to eq("Hello")
      end
    end

    describe "#workflow_config" do
      it "returns hash with delegate_workflow and custom_text" do
        config = form.workflow_config
        expect(config[:delegate_workflow]).to eq(delegate_workflow)
        expect(config[:custom_text]).to eq(custom_text)
      end

      context "with blank values" do
        let(:delegate_workflow) { "" }
        let(:custom_text) { "" }

        it "returns empty hash" do
          expect(form.workflow_config).to eq({})
        end
      end
    end

    describe "#delegate_workflow_options" do
      it "returns available workflows except organization_welcome" do
        result = form.delegate_workflow_options
        workflow_names = result.map(&:last)
        expect(workflow_names).not_to include("organization_welcome")
        expect(workflow_names).to include("single_participatory_space_workflow")
      end
    end
  end
end
