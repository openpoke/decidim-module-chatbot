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
              expect(adapter).to receive(:send_message!).with(
                hash_including(
                  type: :interactive_buttons,
                  footer_text: "Test Process",
                  buttons: array_including(
                    hash_including(id: "more_info"),
                    hash_including(id: "participate")
                  )
                )
              )
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

            it "sends a text message with description and URL" do
              expect(adapter).to receive(:send_message!).with(
                hash_including(
                  body: a_string_including("Detailed description"),
                  preview_url: true
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

            context "without a proposals component" do
              it "sends a not ready message" do
                expect(adapter).to receive(:send_message!).with(
                  I18n.t("decidim.chatbot.workflows.single_participatory_space.not_ready_yet")
                )
                subject.start
              end
            end

            context "with a proposals component" do
              let!(:proposals_component) do
                create(:component, participatory_space: participatory_process, manifest_name: "proposals")
              end
              let(:setting_config) do
                {
                  participatory_space_gid: participatory_process.to_global_id.to_s,
                  component_id: proposals_component.id
                }
              end
              let(:proposals_workflow_instance) { instance_double(ProposalsWorkflow) }

              before do
                allow(ProposalsWorkflow).to receive(:new).and_return(proposals_workflow_instance)
                allow(proposals_workflow_instance).to receive(:start)
              end

              it "delegates to ProposalsWorkflow" do
                expect(proposals_workflow_instance).to receive(:start).with(true)
                subject.start
              end

              it "pushes ProposalsWorkflow to the stack with component_id" do
                subject.start
                sender.reload
                expect(sender.workflow_stack.last["class"]).to eq("Decidim::Chatbot::Workflows::ProposalsWorkflow")
                expect(sender.workflow_stack.last["options"]).to eq({ "component_id" => proposals_component.id })
              end
            end
          end

          context "when user clicks exit button without parent workflow" do
            before do
              allow(received_message).to receive(:user_text?).and_return(false)
              allow(received_message).to receive(:actionable?).and_return(true)
              allow(received_message).to receive(:button_id).and_return("exit")
              sender.update!(workflow_stack: [
                               { "class" => "Decidim::Chatbot::Workflows::SingleParticipatorySpaceWorkflow", "options" => {} }
                             ])
              message.reload
            end

            it "pops from stack and resets workflows" do
              subject.start
              sender.reload
              expect(sender.workflow_stack).to eq([])
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
              allow(received_message).to receive(:button_id).and_return("exit")
              sender.update!(workflow_stack: [
                               { "class" => "Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow", "options" => {} },
                               { "class" => "Decidim::Chatbot::Workflows::SingleParticipatorySpaceWorkflow", "options" => {} }
                             ])
              message.reload
            end

            it "pops current workflow from stack" do
              subject.start
              sender.reload
              expect(sender.workflow_stack.length).to eq(1)
              expect(sender.workflow_stack.last["class"]).to eq("Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow")
            end

            it "does not send a reset message" do
              expect(adapter).not_to receive(:send_message!).with(
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
              expect(adapter).to receive(:send_message!).with(hash_including(type: :interactive_buttons)).ordered
              subject.start
            end
          end

          context "when instructions are not configured" do
            it "sends only the welcome message" do
              expect(adapter).to receive(:send_message!).with(hash_including(type: :interactive_buttons))
              expect(adapter).not_to receive(:send_message!).with("")
              subject.start
            end
          end
        end

        describe "welcome message buttons" do
          before do
            allow(received_message).to receive(:user_text?).and_return(true)
            allow(received_message).to receive(:actionable?).and_return(false)
          end

          context "when no parent_workflow (empty stack)" do
            it "includes 2 buttons (more_info and participate)" do
              expect(adapter).to receive(:send_message!) do |args|
                buttons = args[:buttons]
                expect(buttons.length).to eq(2)
                expect(buttons.map { |b| b[:id] }).to contain_exactly("more_info", "participate")
              end
              subject.start
            end
          end

          context "when parent_workflow exists (stack has 2+ entries)" do
            before do
              sender.update!(workflow_stack: [
                               { "class" => "Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow", "options" => {} },
                               { "class" => "Decidim::Chatbot::Workflows::SingleParticipatorySpaceWorkflow", "options" => {} }
                             ])
              message.reload
            end

            it "includes 3 buttons (more_info, participate, exit)" do
              expect(adapter).to receive(:send_message!) do |args|
                buttons = args[:buttons]
                expect(buttons.length).to eq(3)
                expect(buttons.map { |b| b[:id] }).to contain_exactly("more_info", "participate", "exit")
              end
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
            expect(adapter).to receive(:send_message!) do |args|
              expect(args[:footer_text]).to eq("Test Process")
            end
            subject.start
          end

          it "includes the short description in body" do
            expect(adapter).to receive(:send_message!) do |args|
              expect(args[:body_text]).to include("Short description")
            end
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
              expect(adapter).to receive(:send_message!) do |args|
                expect(args[:body_text]).not_to include("<p>")
                expect(args[:body_text]).not_to include("<strong>")
              end
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
              expect(adapter).to receive(:send_message!) do |args|
                expect(args).to have_key(:header_image)
                expect(args[:header_image]).to be_present
              end
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
              expect(adapter).to receive(:send_message!) do |args|
                expect(args).not_to have_key(:header_image)
              end
              subject.start
            end
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
              I18n.t("decidim.chatbot.workflows.single_participatory_space.no_spaces")
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
              I18n.t("decidim.chatbot.workflows.single_participatory_space.no_spaces")
            )
            subject.start
          end
        end
      end
    end
  end
end
