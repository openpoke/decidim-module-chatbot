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

    describe "#current_workflow_merge!" do
      let(:sender) do
        create(:chatbot_sender, setting:, workflow_stack: [
                 { "class" => "Decidim::Chatbot::Workflows::ProposalsWorkflow", "options" => { "component_id" => 42 } }
               ])
      end

      it "merges new options into existing ones" do
        sender.current_workflow_merge!(page: 2)
        sender.reload
        expect(sender.current_workflow_options).to eq({ "component_id" => 42, "page" => 2 })
      end

      it "overwrites existing keys" do
        sender.current_workflow_merge!(component_id: 99)
        sender.reload
        expect(sender.current_workflow_options["component_id"]).to eq(99)
      end
    end

    describe "#full_workflow_stack" do
      context "when stack is empty and no parent workflow" do
        let(:sender) { build(:chatbot_sender, setting:, workflow_stack: []) }

        it "returns an empty array" do
          expect(sender.full_workflow_stack).to eq([])
        end
      end

      context "when stack already starts with the root workflow" do
        let(:sender) do
          build(:chatbot_sender, setting:, workflow_stack: [
                  { "class" => setting.workflow.name, "options" => {} },
                  { "class" => "Decidim::Chatbot::Workflows::SingleParticipatorySpaceWorkflow", "options" => {} }
                ])
        end

        it "returns the stack unchanged" do
          expect(sender.full_workflow_stack.length).to eq(2)
          expect(sender.full_workflow_stack.first["class"]).to eq(setting.workflow.name)
        end
      end

      context "when stack does not start with root workflow but has parent" do
        let(:sender) do
          build(:chatbot_sender, setting:, workflow_stack: [
                  { "class" => "Decidim::Chatbot::Workflows::SingleParticipatorySpaceWorkflow", "options" => {} },
                  { "class" => "Decidim::Chatbot::Workflows::ProposalsWorkflow", "options" => {} }
                ])
        end

        it "prepends the root workflow to the stack" do
          full_stack = sender.full_workflow_stack
          expect(full_stack.length).to eq(3)
          expect(full_stack.first["class"]).to eq(setting.workflow.name)
        end
      end

      context "when stack has a single non-root entry" do
        let(:sender) do
          build(:chatbot_sender, setting:, workflow_stack: [
                  { "class" => "Decidim::Chatbot::Workflows::SingleParticipatorySpaceWorkflow", "options" => {} }
                ])
        end

        it "prepends the root workflow (parent_workflow falls back to setting workflow)" do
          full_stack = sender.full_workflow_stack
          expect(full_stack.length).to eq(2)
          expect(full_stack.first["class"]).to eq(setting.workflow.name)
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

    describe "#user" do
      let(:sender) { create(:chatbot_sender, setting:, name: "John Doe") }

      context "when decidim_user is already associated" do
        let(:user) { create(:user, organization:) }
        let(:sender) { create(:chatbot_sender, setting:, decidim_user: user, name: "John Doe") }

        it "returns the associated user" do
          expect(sender.user).to eq(user)
        end
      end

      context "when no decidim_user but user exists with matching extended_data" do
        let!(:existing_user) do
          create(:user, organization:, extended_data: { "chatbot_sender_id" => sender.id })
        end

        it "finds and returns that user" do
          expect(sender.user).to eq(existing_user)
        end
      end

      context "when no user exists" do
        it "creates a new Decidim::User" do
          expect { sender.user }.to change(Decidim::User, :count).by(1)
        end

        it "sets correct attributes on the new user" do
          user = sender.user
          expect(user.name).to eq("John Doe")
          expect(user.organization).to eq(organization)
          expect(user.tos_agreement).to be true
          expect(user.managed).to be true
          expect(user.extended_data["chatbot_sender_id"]).to eq(sender.id)
        end

        it "updates the sender's decidim_user association" do
          user = sender.user
          sender.reload
          expect(sender.decidim_user).to eq(user)
        end
      end

      context "when sender name contains special characters" do
        let(:sender) { create(:chatbot_sender, setting:, name: "John <Doe> [Test]") }

        it "cleans special characters from the user name" do
          user = sender.user
          expect(user.name).to eq("John Doe Test")
        end
      end

      context "when sender name is all special characters" do
        let(:sender) { create(:chatbot_sender, setting:, name: "<>[]()") }

        it "falls back to provider + id format" do
          user = sender.user
          expect(user.name).to eq("#{setting.provider.titleize} #{sender.id}")
        end
      end

      context "when called twice" do
        it "returns the same user without creating duplicates" do
          first_call = sender.user
          second_call = sender.user
          expect(first_call).to eq(second_call)
          expect(Decidim::User.where(extended_data: { chatbot_sender_id: sender.id }.to_json).count).to be <= 1
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
