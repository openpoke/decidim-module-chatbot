# frozen_string_literal: true

require "spec_helper"

module Decidim::Chatbot
  describe Sender do
    subject { sender }

    let(:organization) { create(:organization) }
    let(:setting) { create(:chatbot_setting, organization:) }
    let(:sender) { build(:chatbot_sender, setting:) }

    it { is_expected.to be_valid }

    context "without a setting" do
      let(:sender) { build(:chatbot_sender, setting: nil) }

      it { is_expected.not_to be_valid }
    end

    describe "associations" do
      it "belongs to a setting" do
        expect(sender.setting).to eq(setting)
      end

      context "with a user" do
        let(:user) { create(:user, organization:) }
        let(:sender) { build(:chatbot_sender, setting:, decidim_user: user) }

        it "belongs to the user" do
          expect(sender.decidim_user).to eq(user)
        end
      end

      context "without a user" do
        let(:sender) { build(:chatbot_sender, setting:, decidim_user: nil) }

        it "is valid without a user" do
          expect(sender).to be_valid
          expect(sender.decidim_user).to be_nil
        end
      end
    end

    describe "#workflow_stack" do
      context "when nil in DB" do
        let(:sender) { build(:chatbot_sender, setting:, workflow_stack: nil) }

        it "returns an empty array" do
          expect(sender.workflow_stack).to eq([])
        end
      end

      context "when has entries" do
        let(:sender) { build(:chatbot_sender, :with_workflow, setting:) }

        it "returns the array" do
          expect(sender.workflow_stack).to be_an(Array)
          expect(sender.workflow_stack.length).to eq(1)
        end
      end
    end

    describe "#current_workflow" do
      context "when stack has an entry" do
        let(:sender) { build(:chatbot_sender, :with_workflow, setting:) }

        it "returns the workflow class from the last stack entry" do
          expect(sender.current_workflow).to eq(Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow)
        end
      end

      context "when stack is empty" do
        let(:sender) { build(:chatbot_sender, setting:, workflow_stack: []) }

        it "returns the default workflow from setting" do
          expect(sender.current_workflow).to eq(setting.workflow)
        end
      end

      context "with an invalid workflow class in stack" do
        let(:sender) do
          build(:chatbot_sender, setting:, workflow_stack: [{ "class" => "NonExistent::Workflow", "options" => {} }])
        end

        it "falls back to the setting workflow" do
          expect(sender.current_workflow).to eq(setting.workflow)
        end
      end
    end

    describe "#parent_workflow" do
      context "when stack is empty" do
        let(:sender) { build(:chatbot_sender, setting:, workflow_stack: []) }

        it "returns nil" do
          expect(sender.parent_workflow).to be_nil
        end
      end

      context "when stack has one entry" do
        let(:sender) { build(:chatbot_sender, :with_workflow, setting:) }

        it "returns nil" do
          expect(sender.parent_workflow).to be_nil
        end
      end

      context "when stack has two entries" do
        let(:sender) { build(:chatbot_sender, :with_parent_workflow, setting:) }

        it "returns the class from the second-to-last entry" do
          expect(sender.parent_workflow).to eq(Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow)
        end
      end

      context "with an invalid parent class in stack" do
        let(:sender) do
          build(:chatbot_sender, setting:, workflow_stack: [
                  { "class" => "NonExistent::Workflow", "options" => {} },
                  { "class" => "Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow", "options" => {} }
                ])
        end

        it "returns nil" do
          expect(sender.parent_workflow).to be_nil
        end
      end
    end

    describe "#current_workflow_options" do
      context "when stack is empty" do
        it "returns empty hash" do
          expect(sender.current_workflow_options).to eq({})
        end
      end

      context "when last entry has options" do
        let(:sender) do
          build(:chatbot_sender, setting:, workflow_stack: [
                  { "class" => "Decidim::Chatbot::Workflows::ProposalsWorkflow", "options" => { "component_id" => 42, "page" => 2 } }
                ])
        end

        it "returns the options" do
          expect(sender.current_workflow_options).to eq({ "component_id" => 42, "page" => 2 })
        end
      end
    end

    describe "#parent_workflow_options" do
      context "when stack has fewer than 2 entries" do
        it "returns empty hash" do
          expect(sender.parent_workflow_options).to eq({})
        end
      end

      context "when stack has two entries with options" do
        let(:sender) do
          build(:chatbot_sender, setting:, workflow_stack: [
                  { "class" => "Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow", "options" => { "key" => "value" } },
                  { "class" => "Decidim::Chatbot::Workflows::SingleParticipatorySpaceWorkflow", "options" => {} }
                ])
        end

        it "returns options from the second-to-last entry" do
          expect(sender.parent_workflow_options).to eq({ "key" => "value" })
        end
      end
    end

    describe "#current_workflow_options!" do
      context "when stack is empty" do
        let(:sender) { create(:chatbot_sender, setting:, workflow_stack: []) }

        it "initializes stack with setting workflow and options" do
          sender.current_workflow_options!({ page: 1 })
          sender.reload
          expect(sender.workflow_stack.length).to eq(1)
          expect(sender.workflow_stack.last["class"]).to eq(setting.workflow.name)
          expect(sender.workflow_stack.last["options"]).to eq({ "page" => 1 })
        end
      end

      context "when stack has entries" do
        let(:sender) do
          create(:chatbot_sender, setting:, workflow_stack: [
                   { "class" => "Decidim::Chatbot::Workflows::ProposalsWorkflow", "options" => { "component_id" => 42 } }
                 ])
        end

        it "updates options in the last entry and persists" do
          sender.current_workflow_options!({ "page" => 2 })
          sender.reload
          expect(sender.workflow_stack.last["options"]).to eq({ "page" => 2 })
        end
      end
    end

    describe "#push_to_workflow_stack!" do
      let(:sender) { create(:chatbot_sender, setting:) }

      it "adds entry and persists" do
        sender.push_to_workflow_stack!(Decidim::Chatbot::Workflows::SingleParticipatorySpaceWorkflow)
        sender.reload
        expect(sender.workflow_stack.length).to eq(1)
        expect(sender.workflow_stack.last["class"]).to eq("Decidim::Chatbot::Workflows::SingleParticipatorySpaceWorkflow")
      end

      it "preserves existing entries" do
        sender.push_to_workflow_stack!(Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow)
        sender.push_to_workflow_stack!(Decidim::Chatbot::Workflows::SingleParticipatorySpaceWorkflow)
        sender.reload
        expect(sender.workflow_stack.length).to eq(2)
      end

      it "includes options when provided" do
        sender.push_to_workflow_stack!(Decidim::Chatbot::Workflows::ProposalsWorkflow, { component_id: 5 })
        sender.reload
        expect(sender.workflow_stack.last["options"]).to eq({ "component_id" => 5 })
      end

      it "defaults to empty options" do
        sender.push_to_workflow_stack!(Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow)
        sender.reload
        expect(sender.workflow_stack.last["options"]).to eq({})
      end
    end

    describe "#pop_from_workflow_stack!" do
      context "when stack is empty" do
        let(:sender) { create(:chatbot_sender, setting:, workflow_stack: []) }

        it "returns nil" do
          expect(sender.pop_from_workflow_stack!).to be_nil
        end
      end

      context "when stack has entries" do
        let(:sender) do
          create(:chatbot_sender, setting:, workflow_stack: [
                   { "class" => "Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow", "options" => {} },
                   { "class" => "Decidim::Chatbot::Workflows::SingleParticipatorySpaceWorkflow", "options" => {} }
                 ])
        end

        it "removes the last entry and persists" do
          sender.pop_from_workflow_stack!
          sender.reload
          expect(sender.workflow_stack.length).to eq(1)
          expect(sender.workflow_stack.last["class"]).to eq("Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow")
        end
      end
    end

    describe "#clear_workflow_stack!" do
      let(:sender) do
        create(:chatbot_sender, :with_parent_workflow, setting:)
      end

      it "clears the stack to empty array and persists" do
        sender.clear_workflow_stack!
        sender.reload
        expect(sender.workflow_stack).to eq([])
      end

      context "when already empty" do
        let(:sender) { create(:chatbot_sender, setting:, workflow_stack: []) }

        it "does not raise error" do
          expect { sender.clear_workflow_stack! }.not_to raise_error
          expect(sender.workflow_stack).to eq([])
        end
      end
    end

    describe "#locale" do
      context "when metadata contains locale" do
        let(:sender) { build(:chatbot_sender, setting:, metadata: { "locale" => "ca" }) }

        it "returns the locale from metadata" do
          expect(sender.locale).to eq("ca")
        end
      end

      context "when user has a locale" do
        let(:user) { create(:user, organization:, locale: "ca") }
        let(:sender) { build(:chatbot_sender, setting:, decidim_user: user, metadata: {}) }

        it "returns the user locale" do
          expect(sender.locale).to eq("ca")
        end
      end

      context "when neither metadata nor user has locale" do
        let(:sender) { build(:chatbot_sender, setting:, decidim_user: nil, metadata: {}) }

        it "returns the organization default locale" do
          expect(sender.locale).to eq(organization.default_locale)
        end
      end

      context "with locale priority" do
        let(:user) { create(:user, organization:, locale: "ca") }
        let(:sender) { build(:chatbot_sender, setting:, decidim_user: user, metadata: { "locale" => "fr" }) }

        it "prefers metadata locale over user locale" do
          expect(sender.locale).to eq("fr")
        end
      end
    end
  end
end
