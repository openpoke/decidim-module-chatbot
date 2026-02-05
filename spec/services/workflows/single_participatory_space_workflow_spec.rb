# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Chatbot
    module Workflows
      describe SingleParticipatorySpaceWorkflow do
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
            participatory_space_gid: participatory_process.to_global_id.to_s
          }
        end
        let(:setting) { create(:chatbot_setting, organization:, enabled: true, config: setting_config) }
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
          it "creates an instance of SingleParticipatorySpaceWorkflow" do
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
                    hash_including(id: "more_info"),
                    hash_including(id: "participate"),
                    hash_including(id: "end")
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

          context "when user clicks more_info button" do
            before do
              allow(received_message).to receive(:user_text?).and_return(false)
              allow(received_message).to receive(:actionable?).and_return(true)
              allow(received_message).to receive(:button_id).and_return("more_info")
              participatory_process.update!(description: { en: "Detailed description of the process" })
            end

            it "sends the full description" do
              expect(adapter).to receive(:send_message!).with(include("Detailed description"))
              subject.start
            end

            it "then resends the welcome message" do
              expect(adapter).to receive(:send_message!).with(include("Detailed description"))
              expect(adapter).to receive(:send!).with(envelope)
              subject.start
            end
          end

          context "when user clicks participate button" do
            before do
              allow(received_message).to receive(:user_text?).and_return(false)
              allow(received_message).to receive(:actionable?).and_return(true)
              allow(received_message).to receive(:button_id).and_return("participate")
            end

            it "sends a not ready message" do
              expect(adapter).to receive(:send_message!).with(
                I18n.t("decidim.chatbot.workflows.single_participatory_space_workflow.not_ready_yet")
              )
              subject.start
            end
          end

          context "when user clicks exit button without parent workflow" do
            before do
              allow(received_message).to receive(:user_text?).and_return(false)
              allow(received_message).to receive(:actionable?).and_return(true)
              allow(received_message).to receive(:button_id).and_return("end")
              sender.update!(parent_workflow_class: nil)
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

          context "when user clicks exit button with parent workflow" do
            before do
              allow(received_message).to receive(:user_text?).and_return(false)
              allow(received_message).to receive(:actionable?).and_return(true)
              allow(received_message).to receive(:button_id).and_return("end")
              sender.update!(parent_workflow_class: "Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow")
            end

            it "delegates back to parent workflow" do
              parent_workflow_instance = instance_double(Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow)
              allow(Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow).to receive(:new).and_return(parent_workflow_instance)
              allow(parent_workflow_instance).to receive(:start)

              subject.start
              sender.reload
              expect(sender.current_workflow_class).to eq("Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow")
              expect(sender.parent_workflow_class).to be_nil
            end
          end
        end

        describe "instructions handling" do
          before do
            allow(received_message).to receive(:user_text?).and_return(true)
            allow(received_message).to receive(:actionable?).and_return(false)
          end

          context "when instructions are configured" do
            let(:setting_config) do
              {
                participatory_space_gid: participatory_process.to_global_id.to_s,
                instructions: "These are custom instructions for the user"
              }
            end

            it "sends the instructions before the welcome message" do
              expect(adapter).to receive(:send_message!).with("These are custom instructions for the user").ordered
              expect(adapter).to receive(:send!).ordered
              subject.start
            end
          end

          context "when instructions are not configured" do
            it "skips instructions and sends welcome message" do
              expect(adapter).not_to receive(:send_message!).with("")
              expect(adapter).to receive(:send!).with(envelope)
              subject.start
            end
          end
        end

        describe "welcome message content" do
          before do
            allow(received_message).to receive(:user_text?).and_return(true)
            allow(received_message).to receive(:actionable?).and_return(false)
          end

          it "includes all action buttons" do
            expect(adapter).to receive(:build_message) do |args|
              buttons = args[:data][:buttons]
              expect(buttons.length).to eq(3)
              expect(buttons.map { |b| b[:id] }).to contain_exactly("more_info", "participate", "end")
            end.and_return(envelope)
            subject.start
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
          let(:setting) { create(:chatbot_setting, organization:, enabled: false, config: setting_config) }

          before do
            allow(received_message).to receive(:user_text?).and_return(true)
            allow(received_message).to receive(:actionable?).and_return(false)
          end

          it "sends a not configured message" do
            expect(adapter).to receive(:send_message!).with(
              I18n.t("decidim.chatbot.workflows.single_participatory_space_workflow.not_configured")
            )
            subject.start
          end
        end

        describe "when no participatory spaces exist" do
          let(:setting_config) do
            {
              participatory_space_gid: "gid://decidim/Decidim::ParticipatoryProcess/999999"
            }
          end

          before do
            allow(received_message).to receive(:user_text?).and_return(true)
            allow(received_message).to receive(:actionable?).and_return(false)
          end

          it "sends a no spaces message" do
            expect(adapter).to receive(:send_message!).with(
              I18n.t("decidim.chatbot.workflows.single_participatory_space_workflow.no_spaces")
            )
            subject.start
          end
        end

        describe "when participatory_space_gid is blank" do
          let(:setting_config) { {} }

          before do
            allow(received_message).to receive(:user_text?).and_return(true)
            allow(received_message).to receive(:actionable?).and_return(false)
          end

          it "sends a no spaces message" do
            expect(adapter).to receive(:send_message!).with(
              I18n.t("decidim.chatbot.workflows.single_participatory_space_workflow.no_spaces")
            )
            subject.start
          end
        end
      end
    end
  end
end
