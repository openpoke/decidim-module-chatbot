# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Chatbot
    module Workflows
      describe ParticipatorySpaceWorkflow do
        subject { described_class.new(adapter:, message:) }

        let(:organization) { create(:organization) }
        let!(:participatory_process) do
          create(:participatory_process,
                 organization:,
                 title: { en: "Test Process" },
                 short_description: { en: "Short description of the process" })
        end
        let(:setting_config) do
          {
            enabled: true,
            participatory_space_type: "Decidim::ParticipatoryProcess",
            participatory_space_id: participatory_process.id
          }
        end
        let(:setting) { create(:chatbot_setting, organization:, config: setting_config) }
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
          it "creates an instance of ParticipatorySpaceWorkflow" do
            expect(subject).to be_a(described_class)
          end
        end

        describe "#start" do
          context "when user sends a text message" do
            before do
              allow(received_message).to receive(:user_text?).and_return(true)
              allow(received_message).to receive(:actionable?).and_return(false)
            end

            it "sends a welcome message with participatory space info" do
              expect(adapter).to receive(:build_message).with(
                to: "123456789",
                type: :interactive_buttons,
                data: hash_including(
                  footer_text: "Test Process",
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
            before do
              allow(received_message).to receive(:user_text?).and_return(false)
              allow(received_message).to receive(:actionable?).and_return(true)
              allow(received_message).to receive(:button_id).and_return("start")
            end

            it "sends a participate prompt message" do
              expect(adapter).to receive(:build_message).with(
                to: "123456789",
                type: :interactive_buttons,
                data: hash_including(
                  buttons: array_including(
                    hash_including(id: "participate")
                  )
                )
              )
              subject.start
            end
          end

          context "when user clicks participate button" do
            before do
              allow(received_message).to receive(:user_text?).and_return(false)
              allow(received_message).to receive(:actionable?).and_return(true)
              allow(received_message).to receive(:button_id).and_return("participate")
            end

            context "when write_action is configured" do
              let(:setting_config) do
                {
                  enabled: true,
                  participatory_space_type: "Decidim::ParticipatoryProcess",
                  participatory_space_id: participatory_process.id,
                  write_action: "create_proposal"
                }
              end

              it "sends a coming soon message" do
                expect(adapter).to receive(:send_message!).with(
                  I18n.t("decidim.chatbot.workflows.participatory_space_workflow.write_actions.coming_soon")
                )
                subject.start
              end
            end

            context "when write_action is not configured" do
              let(:setting_config) do
                {
                  enabled: true,
                  participatory_space_type: "Decidim::ParticipatoryProcess",
                  participatory_space_id: participatory_process.id,
                  write_action: nil
                }
              end

              it "sends a read-only mode message" do
                expect(adapter).to receive(:send_message!).with(
                  I18n.t("decidim.chatbot.workflows.participatory_space_workflow.read_only_mode")
                )
                subject.start
              end
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
            it "includes only the start button" do
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
              sender.update!(parent_workflow_class: "Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow")
            end

            it "includes both start and end buttons" do
              expect(adapter).to receive(:build_message) do |args|
                buttons = args[:data][:buttons]
                expect(buttons.length).to eq(2)
                expect(buttons.map { |b| b[:id] }).to contain_exactly("start", "end")
              end.and_return(envelope)
              subject.start
            end
          end
        end

        describe "participatory space content" do
          before do
            allow(received_message).to receive(:user_text?).and_return(true)
            allow(received_message).to receive(:actionable?).and_return(false)
          end

          it "includes the participatory space title in footer" do
            expect(adapter).to receive(:build_message) do |args|
              expect(args[:data][:footer_text]).to eq("Test Process")
            end.and_return(envelope)
            subject.start
          end

          it "includes the short description in body" do
            expect(adapter).to receive(:build_message) do |args|
              expect(args[:data][:body_text]).to include("Short description")
            end.and_return(envelope)
            subject.start
          end

          context "with HTML in description" do
            let!(:participatory_process) do
              create(:participatory_process,
                     organization:,
                     title: { en: "Test Process" },
                     short_description: { en: "<p>Description with <strong>HTML</strong></p>" })
            end

            it "strips HTML tags" do
              expect(adapter).to receive(:build_message) do |args|
                body_text = args[:data][:body_text]
                expect(body_text).not_to include("<p>")
                expect(body_text).not_to include("<strong>")
              end.and_return(envelope)
              subject.start
            end
          end

          context "with hero image attached" do
            let!(:participatory_process) do
              process = create(:participatory_process,
                               organization:,
                               title: { en: "Test Process" },
                               short_description: { en: "Description" })
              process.hero_image.attach(
                io: File.open(Decidim::Dev.asset("city.jpeg")),
                filename: "city.jpeg",
                content_type: "image/jpeg"
              )
              process
            end

            it "includes header_image in the message" do
              expect(adapter).to receive(:build_message) do |args|
                expect(args[:data]).to have_key(:header_image)
                expect(args[:data][:header_image]).to be_present
              end.and_return(envelope)
              subject.start
            end
          end

          context "without hero image" do
            let!(:participatory_process) do
              create(:participatory_process,
                     :unpublished,
                     organization:,
                     title: { en: "Test Process" },
                     short_description: { en: "Description" },
                     hero_image: nil)
            end

            before do
              participatory_process.hero_image.purge if participatory_process.hero_image.attached?
              participatory_process.publish!
            end

            it "does not include header_image" do
              expect(adapter).to receive(:build_message) do |args|
                expect(args[:data]).not_to have_key(:header_image)
              end.and_return(envelope)
              subject.start
            end
          end
        end

        describe "when chatbot is not enabled" do
          let(:setting_config) { { enabled: false } }

          before do
            allow(received_message).to receive(:user_text?).and_return(true)
            allow(received_message).to receive(:actionable?).and_return(false)
          end

          it "sends a not configured message" do
            expect(adapter).to receive(:send_message!).with(
              I18n.t("decidim.chatbot.workflows.participatory_space_workflow.not_configured")
            )
            subject.start
          end
        end

        describe "when no participatory spaces exist" do
          let(:setting_config) do
            {
              enabled: true,
              participatory_space_type: "Decidim::ParticipatoryProcess",
              participatory_space_id: 999_999
            }
          end

          before do
            allow(received_message).to receive(:user_text?).and_return(true)
            allow(received_message).to receive(:actionable?).and_return(false)
          end

          it "sends a no spaces message" do
            expect(adapter).to receive(:send_message!).with(
              I18n.t("decidim.chatbot.workflows.participatory_space_workflow.no_spaces")
            )
            subject.start
          end
        end
      end
    end
  end
end
