# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Chatbot
    module Workflows
      describe OrganizationWelcomeWorkflow do
        subject { described_class.new(adapter:, message:) }

        let(:organization) { create(:organization, name: { en: "Test Organization" }, description: { en: "Test Description" }) }
        let(:setting) { create(:chatbot_setting, organization:) }
        let(:sender) { create(:chatbot_sender, setting:) }
        let(:message) { create(:chatbot_message, setting:, sender:) }
        let(:adapter) { instance_double(Providers::Whatsapp::Adapter) }
        let(:envelope) { instance_double(Providers::Whatsapp::Envelopes::InteractiveButtons) }
        let(:received_message) do
          instance_double(
            Providers::Whatsapp::MessageNormalizer,
            from: "123456789",
            message_id: "msg-123",
            user_text?: true,
            actionable?: false,
            acknowledgeable?: true,
            button_id: nil
          )
        end

        before do
          allow(adapter).to receive(:received_message).and_return(received_message)
          allow(adapter).to receive(:mark_as_read!)
          allow(adapter).to receive(:build_message).and_return(envelope)
          allow(adapter).to receive(:send!)
          allow(adapter).to receive(:send_message!)
        end

        describe "#initialize" do
          it "creates an instance of OrganizationWelcomeWorkflow" do
            expect(subject).to be_a(described_class)
          end
        end

        describe "#start" do
          context "when user sends a text message" do
            before do
              allow(received_message).to receive(:user_text?).and_return(true)
              allow(received_message).to receive(:actionable?).and_return(false)
            end

            it "sends a welcome message with organization info" do
              expect(adapter).to receive(:build_message).with(
                to: "123456789",
                type: :interactive_buttons,
                data: hash_including(
                  header_text: "Test Organization",
                  buttons: array_including(
                    hash_including(id: "start")
                  )
                )
              )
              subject.start
            end

            it "sends the message via adapter" do
              expect(adapter).to receive(:send!).with(envelope)
              subject.start
            end

            it "marks the message as read" do
              expect(adapter).to receive(:mark_as_read!)
              subject.start
            end
          end

          context "when user clicks start button" do
            let(:participatory_space_workflow_instance) { instance_double(ParticipatorySpaceWorkflow) }

            before do
              allow(received_message).to receive(:user_text?).and_return(false)
              allow(received_message).to receive(:actionable?).and_return(true)
              allow(received_message).to receive(:button_id).and_return("start")
              allow(ParticipatorySpaceWorkflow).to receive(:new).and_return(participatory_space_workflow_instance)
              allow(participatory_space_workflow_instance).to receive(:start)
            end

            it "delegates to ParticipatorySpaceWorkflow" do
              expect(participatory_space_workflow_instance).to receive(:start).with(true)
              subject.start
            end

            it "updates sender's current_workflow_class" do
              subject.start
              sender.reload
              expect(sender.current_workflow_class).to eq("Decidim::Chatbot::Workflows::ParticipatorySpaceWorkflow")
            end

            it "sets parent_workflow_class to current workflow" do
              subject.start
              sender.reload
              expect(sender.parent_workflow_class).to eq("Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow")
            end
          end

          context "when user clicks end button" do
            before do
              allow(received_message).to receive(:user_text?).and_return(false)
              allow(received_message).to receive(:actionable?).and_return(true)
              allow(received_message).to receive(:button_id).and_return("end")
              sender.update!(
                current_workflow_class: "SomeWorkflow",
                parent_workflow_class: "ParentWorkflow"
              )
            end

            it "resets all workflows" do
              subject.start
              sender.reload
              expect(sender.current_workflow_class).to be_nil
              expect(sender.parent_workflow_class).to be_nil
            end

            it "sends a reset confirmation message" do
              expect(adapter).to receive(:send_message!).with(
                I18n.t("decidim.chatbot.messages.reset_workflows")
              )
              subject.start
            end
          end
        end

        describe "welcome message content" do
          before do
            allow(received_message).to receive(:user_text?).and_return(true)
            allow(received_message).to receive(:actionable?).and_return(false)
          end

          context "when parent_workflow is nil" do
            it "includes only the participate button" do
              expect(adapter).to receive(:build_message) do |args|
                buttons = args[:data][:buttons]
                expect(buttons.length).to eq(1)
                expect(buttons.first[:id]).to eq("start")
              end.and_return(envelope)
              subject.start
            end
          end

          context "when parent_workflow exists" do
            before do
              sender.update!(parent_workflow_class: "Decidim::Chatbot::Workflows::BaseWorkflow")
            end

            it "includes both participate and end buttons" do
              expect(adapter).to receive(:build_message) do |args|
                buttons = args[:data][:buttons]
                expect(buttons.length).to eq(2)
                expect(buttons.map { |b| b[:id] }).to contain_exactly("start", "end")
              end.and_return(envelope)
              subject.start
            end
          end
        end

        describe "organization content sanitization" do
          let(:organization) do
            create(:organization,
                   name: { en: "Organization" },
                   description: { en: "<p>Description with <strong>HTML</strong></p>" })
          end

          before do
            allow(received_message).to receive(:user_text?).and_return(true)
            allow(received_message).to receive(:actionable?).and_return(false)
          end

          it "strips HTML tags from description" do
            expect(adapter).to receive(:build_message) do |args|
              body_text = args[:data][:body_text]
              expect(body_text).not_to include("<p>")
              expect(body_text).not_to include("<strong>")
              expect(body_text).to include("Description with HTML")
            end.and_return(envelope)
            subject.start
          end
        end
      end
    end
  end
end
