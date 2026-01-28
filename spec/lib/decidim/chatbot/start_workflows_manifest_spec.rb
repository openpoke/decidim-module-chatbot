# frozen_string_literal: true

require "spec_helper"

module Decidim::Chatbot
  describe StartWorkflowsManifest do
    subject { manifest }

    let(:manifest) do
      described_class.new(
        name: :test_workflow,
        workflow_class: workflow_class,
        settings_partial: settings_partial,
        settings_attributes: settings_attributes
      )
    end

    let(:workflow_class) { "Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow" }
    let(:settings_partial) { "decidim/chatbot/admin/settings/workflows/welcome" }
    let(:settings_attributes) do
      {
        custom_text: { type: :text, required: false },
        delegate_workflow: { type: :select, required: false }
      }
    end

    describe "#configurable?" do
      context "when settings_partial is present" do
        it "returns true" do
          expect(manifest.configurable?).to be true
        end
      end

      context "when settings_partial is nil" do
        let(:settings_partial) { nil }

        it "returns false" do
          expect(manifest.configurable?).to be false
        end
      end

      context "when settings_partial is empty string" do
        let(:settings_partial) { "" }

        it "returns false" do
          expect(manifest.configurable?).to be false
        end
      end
    end

    describe "#config_keys" do
      it "returns string keys from settings_attributes" do
        expect(manifest.config_keys).to contain_exactly("custom_text", "delegate_workflow")
      end

      context "when settings_attributes is empty" do
        let(:settings_attributes) { {} }

        it "returns an empty array" do
          expect(manifest.config_keys).to eq([])
        end
      end
    end

    describe "#title" do
      let(:manifest) do
        described_class.new(
          name: :organization_welcome,
          workflow_class: workflow_class,
          settings_partial: settings_partial,
          settings_attributes: settings_attributes
        )
      end

      it "returns a translated string" do
        expect(manifest.title).to be_a(String)
        expect(manifest.title).not_to include("translation missing")
      end
    end

    describe "#workflow" do
      context "with a valid workflow_class" do
        it "returns the constantized class" do
          expect(manifest.workflow).to eq(Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow)
        end
      end

      context "with an invalid workflow_class" do
        let(:workflow_class) { "NonExistent::WorkflowClass" }

        it "returns nil" do
          expect(manifest.workflow).to be_nil
        end
      end
    end
  end
end
