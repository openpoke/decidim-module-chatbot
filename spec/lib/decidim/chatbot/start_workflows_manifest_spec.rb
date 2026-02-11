# frozen_string_literal: true

require "spec_helper"

module Decidim::Chatbot
  describe StartWorkflowsManifest do
    subject { manifest }

    let(:manifest) do
      described_class.new(
        name: :test_workflow,
        workflow_class: workflow_class,
        settings_partial: settings_partial
      )
    end

    let(:workflow_class) { "Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow" }
    let(:settings_partial) { "decidim/chatbot/admin/settings/workflows/welcome" }

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

    describe "#model_class_name" do
      it "returns the workflow_class as a string" do
        expect(manifest.model_class_name).to eq("Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow")
      end
    end

    describe "#title" do
      let(:manifest) do
        described_class.new(
          name: :organization_welcome,
          workflow_class: workflow_class,
          settings_partial: settings_partial
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

    describe "#form" do
      context "when form_class is set" do
        let(:manifest) do
          described_class.new(
            name: :test_workflow,
            workflow_class: workflow_class,
            settings_partial: settings_partial,
            form_class: "Decidim::Chatbot::Admin::SingleParticipatorySpaceSettingsForm"
          )
        end

        it "returns the constantized class" do
          expect(manifest.form).to eq(Decidim::Chatbot::Admin::SingleParticipatorySpaceSettingsForm)
        end
      end

      context "when form_class is nil" do
        it "returns the default SettingForm" do
          expect(manifest.form).to eq(Decidim::Chatbot::Admin::SettingForm)
        end
      end
    end
  end
end
