# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Chatbot
    module Workflows
      describe BaseWorkflow do
        subject { described_class.new(adapter:, message:) }

        let(:organization) { create(:organization) }
        let(:setting) { create(:chatbot_setting, organization:) }
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
            acknowledgeable?: true
          )
        end

        before do
          allow(adapter).to receive(:received_message).and_return(received_message)
          allow(adapter).to receive(:mark_as_read!)
          allow(adapter).to receive(:mark_as_responding!)
          allow(adapter).to receive(:build_message)
          allow(adapter).to receive(:send!)
          allow(adapter).to receive(:send_message!)
        end

        describe "#initialize" do
          it "stores the adapter" do
            expect(subject.adapter).to eq(adapter)
          end

          it "stores the message" do
            expect(subject.message).to eq(message)
          end

          context "with additional options" do
            subject { described_class.new(adapter:, message:, custom_option: "value") }

            it "stores options" do
              expect(subject.options[:custom_option]).to eq("value")
            end
          end
        end

        describe "delegations" do
          it "delegates build_message to adapter" do
            subject.build_message(data: { body: "test" })
            expect(adapter).to have_received(:build_message).with(data: { body: "test" })
          end

          it "delegates send_message! to adapter" do
            subject.send_message!("test message")
            expect(adapter).to have_received(:send_message!).with("test message")
          end

          it "delegates received_message to adapter" do
            expect(subject.received_message).to eq(received_message)
          end

          it "delegates setting to message" do
            expect(subject.setting).to eq(setting)
          end

          it "delegates sender to message" do
            expect(subject.sender).to eq(sender)
          end

          it "delegates organization to setting" do
            expect(subject.organization).to eq(organization)
          end

          it "delegates current_workflow to sender" do
            expect(subject.current_workflow).to eq(sender.current_workflow)
          end

          it "delegates parent_workflow to sender" do
            expect(subject.parent_workflow).to eq(sender.parent_workflow)
          end
        end

        describe "#start" do
          context "when received_message is user_text" do
            before do
              allow(received_message).to receive(:user_text?).and_return(true)
              allow(received_message).to receive(:actionable?).and_return(false)
            end

            it "calls mark_as_read" do
              expect { subject.start }.to raise_error(NotImplementedError)
              expect(adapter).to have_received(:mark_as_read!)
            end

            it "calls process_user_input" do
              expect { subject.start }.to raise_error(NotImplementedError)
            end
          end

          context "when received_message is actionable" do
            before do
              allow(received_message).to receive(:user_text?).and_return(false)
              allow(received_message).to receive(:actionable?).and_return(true)
              allow(received_message).to receive(:button_id).and_return("some_action")
            end

            it "calls mark_as_read" do
              expect { subject.start }.to raise_error(NotImplementedError)
              expect(adapter).to have_received(:mark_as_read!)
            end

            it "calls process_action_input" do
              expect { subject.start }.to raise_error(NotImplementedError)
            end
          end

          context "with force_welcome=true" do
            before do
              allow(received_message).to receive(:user_text?).and_return(false)
              allow(received_message).to receive(:actionable?).and_return(false)
            end

            it "calls process_user_input" do
              expect { subject.start(true) }.to raise_error(NotImplementedError)
            end
          end

          context "when message is not acknowledgeable" do
            before do
              allow(received_message).to receive(:acknowledgeable?).and_return(false)
              allow(received_message).to receive(:user_text?).and_return(true)
            end

            it "does not call mark_as_read on adapter" do
              expect { subject.start }.to raise_error(NotImplementedError)
              expect(adapter).not_to have_received(:mark_as_read!)
            end
          end
        end

        describe "#delegate_workflow" do
          let(:new_workflow_class) { Workflows::SingleParticipatorySpaceWorkflow }
          let(:new_workflow_instance) { instance_double(new_workflow_class) }

          before do
            allow(new_workflow_class).to receive(:new).and_return(new_workflow_instance)
            allow(new_workflow_instance).to receive(:start)
          end

          it "pushes the new workflow to the stack" do
            subject.send(:delegate_workflow, new_workflow_class)
            sender.reload
            expect(sender.workflow_stack.last["class"]).to eq(new_workflow_class.name)
          end

          it "preserves existing stack entries" do
            sender.update!(workflow_stack: [
                             { "class" => "Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow", "options" => {} }
                           ])
            subject.send(:delegate_workflow, new_workflow_class)
            sender.reload
            expect(sender.workflow_stack.length).to eq(2)
          end

          it "starts the new workflow with force_welcome=true" do
            expect(new_workflow_instance).to receive(:start).with(true)
            subject.send(:delegate_workflow, new_workflow_class)
          end

          it "passes config to the new workflow" do
            subject.send(:delegate_workflow, new_workflow_class, { component_id: 42 })
            sender.reload
            expect(sender.workflow_stack.last["options"]).to eq({ "component_id" => 42 })
          end
        end

        describe "#reset_workflows" do
          it "clears the workflow stack" do
            sender.update!(workflow_stack: [
                             { "class" => "Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow", "options" => {} },
                             { "class" => "Decidim::Chatbot::Workflows::SingleParticipatorySpaceWorkflow", "options" => {} }
                           ])

            subject.send(:reset_workflows)
            sender.reload

            expect(sender.workflow_stack).to eq([])
          end

          it "sends a reset message" do
            expect(adapter).to receive(:send_message!).with(
              I18n.t("decidim.chatbot.messages.reset_workflows")
            )
            subject.send(:reset_workflows)
          end
        end

        describe "#exit_workflow" do
          context "when stack has one entry" do
            before do
              sender.update!(workflow_stack: [
                               { "class" => "Decidim::Chatbot::Workflows::SingleParticipatorySpaceWorkflow", "options" => {} }
                             ])
            end

            it "pops from stack" do
              subject.send(:exit_workflow)
              sender.reload
              expect(sender.workflow_stack).to eq([])
            end

            it "restarts the default workflow with force_welcome" do
              expect(adapter).to receive(:send_message!)
              subject.send(:exit_workflow)
            end
          end

          context "when stack has two entries" do
            before do
              sender.update!(workflow_stack: [
                               { "class" => "Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow", "options" => {} },
                               { "class" => "Decidim::Chatbot::Workflows::SingleParticipatorySpaceWorkflow", "options" => {} }
                             ])
            end

            it "pops only the current workflow" do
              subject.send(:exit_workflow)
              sender.reload
              expect(sender.workflow_stack.length).to eq(1)
              expect(sender.workflow_stack.last["class"]).to eq("Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow")
            end

            it "does not send reset message" do
              expect(adapter).not_to receive(:send_message!).with(
                I18n.t("decidim.chatbot.messages.reset_workflows")
              )
              subject.send(:exit_workflow)
            end
          end
        end

        describe "#mark_as_responding" do
          context "when message is acknowledgeable" do
            before do
              allow(received_message).to receive(:acknowledgeable?).and_return(true)
            end

            it "calls mark_as_responding! on adapter" do
              subject.send(:mark_as_responding)
              expect(adapter).to have_received(:mark_as_responding!)
            end
          end

          context "when message is not acknowledgeable" do
            before do
              allow(received_message).to receive(:acknowledgeable?).and_return(false)
            end

            it "does not call mark_as_responding! on adapter" do
              subject.send(:mark_as_responding)
              expect(adapter).not_to have_received(:mark_as_responding!)
            end
          end
        end

        describe "#config" do
          context "without options" do
            it "returns setting config" do
              setting.update!(config: { "key" => "value" })
              expect(subject.send(:config)["key"]).to eq("value")
            end
          end

          context "with options that override setting config" do
            subject { described_class.new(adapter:, message:, key: "overridden") }

            before do
              setting.update!(config: { "key" => "original" })
            end

            it "options take precedence" do
              expect(subject.send(:config)[:key]).to eq("overridden")
            end
          end
        end

        describe "#current_page" do
          context "without page in config" do
            it "returns 1" do
              expect(subject.send(:current_page)).to eq(1)
            end
          end

          context "with page in options" do
            subject { described_class.new(adapter:, message:, page: 3) }

            it "returns the configured page" do
              expect(subject.send(:current_page)).to eq(3)
            end
          end
        end

        describe "#per_page" do
          it "returns 10" do
            expect(subject.send(:per_page)).to eq(10)
          end
        end

        describe "#start — exit/reset button handling" do
          context "when actionable message with button_id 'exit'" do
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

            it "pops from stack" do
              subject.start
              sender.reload
              expect(sender.workflow_stack.length).to eq(1)
            end
          end

          context "when actionable message with button_id 'reset'" do
            before do
              allow(received_message).to receive(:user_text?).and_return(false)
              allow(received_message).to receive(:actionable?).and_return(true)
              allow(received_message).to receive(:button_id).and_return("reset")
              sender.update!(workflow_stack: [
                               { "class" => "Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow", "options" => {} }
                             ])
              message.reload
            end

            it "clears the stack" do
              subject.start
              sender.reload
              expect(sender.workflow_stack).to eq([])
            end

            it "sends reset message" do
              expect(adapter).to receive(:send_message!).with(
                I18n.t("decidim.chatbot.messages.reset_workflows")
              )
              subject.start
            end
          end

          context "when message is neither user_text nor actionable" do
            before do
              allow(received_message).to receive(:user_text?).and_return(false)
              allow(received_message).to receive(:actionable?).and_return(false)
            end

            it "sends unprocessable_input message" do
              expect(adapter).to receive(:send_message!).with(
                hash_including(
                  type: :interactive_buttons,
                  body_text: I18n.t("decidim.chatbot.workflows.base.unprocessable_input")
                )
              )
              subject.start
            end
          end
        end

        describe "#process_unprocessable_input" do
          context "when parent_workflow exists" do
            before do
              sender.update!(workflow_stack: [
                               { "class" => "Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow", "options" => {} },
                               { "class" => "Decidim::Chatbot::Workflows::SingleParticipatorySpaceWorkflow", "options" => {} }
                             ])
              message.reload
            end

            it "includes both reset and exit buttons" do
              expect(adapter).to receive(:send_message!) do |args|
                button_ids = args[:buttons].map { |b| b[:id] }
                expect(button_ids).to include("reset", "exit")
              end
              subject.send(:process_unprocessable_input)
            end
          end

          context "when no parent_workflow (root level)" do
            it "includes only reset button (no exit)" do
              expect(adapter).to receive(:send_message!) do |args|
                button_ids = args[:buttons].map { |b| b[:id] }
                expect(button_ids).to include("reset")
                expect(button_ids).not_to include("exit")
              end
              subject.send(:process_unprocessable_input)
            end
          end
        end

        describe "#start — error handling" do
          let(:error_workflow_class) do
            Class.new(BaseWorkflow) do
              def process_user_input
                raise StandardError, "test error"
              end
            end
          end

          let(:error_workflow) { error_workflow_class.new(adapter:, message:) }

          before do
            allow(received_message).to receive(:user_text?).and_return(true)
            allow(received_message).to receive(:actionable?).and_return(false)
          end

          it "sends generic error message and re-raises" do
            expect(adapter).to receive(:send_message!).with(
              I18n.t("decidim.chatbot.messages.generic_error")
            )
            expect { error_workflow.start }.to raise_error(StandardError, "test error")
          end

          it "sends error details in non-production" do
            allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
            expect(adapter).to receive(:send_message!).with(
              I18n.t("decidim.chatbot.messages.generic_error")
            ).ordered
            expect(adapter).to receive(:send_message!).with(
              a_string_including("test error")
            ).ordered
            expect { error_workflow.start }.to raise_error(StandardError)
          end
        end

        describe "#exit_workflow with_welcome parameter" do
          context "with with_welcome=false" do
            before do
              sender.update!(workflow_stack: [
                               { "class" => "Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow", "options" => {} },
                               { "class" => "Decidim::Chatbot::Workflows::SingleParticipatorySpaceWorkflow", "options" => {} }
                             ])
              message.reload
            end

            it "only pops from stack without restarting parent" do
              expect(adapter).not_to receive(:send_message!)
              subject.send(:exit_workflow, false)
              sender.reload
              expect(sender.workflow_stack.length).to eq(1)
            end
          end
        end

        describe "#sanitize_text" do
          it "strips HTML tags from translated text" do
            text = { "en" => "<p>Hello <strong>world</strong></p>" }
            result = subject.send(:sanitize_text, text)
            expect(result).not_to include("<p>")
            expect(result).not_to include("<strong>")
            expect(result).to include("Hello world")
          end

          it "preserves line breaks from br tags" do
            text = { "en" => "Line 1<br>Line 2<br/>Line 3<br />Line 4" }
            result = subject.send(:sanitize_text, text)
            expect(result).to eq("Line 1\nLine 2\nLine 3\nLine 4")
          end

          it "converts paragraph tags to double newlines" do
            text = { "en" => "<p>First paragraph</p><p>Second paragraph</p>" }
            result = subject.send(:sanitize_text, text)
            expect(result).to eq("First paragraph\n\nSecond paragraph")
          end

          it "converts div tags to newlines" do
            text = { "en" => "<div>First div</div><div>Second div</div>" }
            result = subject.send(:sanitize_text, text)
            expect(result).to eq("First div\nSecond div")
          end

          it "converts heading tags to bold text with double newlines" do
            text = { "en" => "<h1>Main Title</h1><p>Content here</p><h2>Subtitle</h2><p>More content</p>" }
            result = subject.send(:sanitize_text, text)
            expect(result).to eq("*Main Title*\n\nContent here\n\n*Subtitle*\n\nMore content")
          end

          it "cleans up excessive consecutive newlines" do
            text = { "en" => "<p>Para 1</p><br><br><br><p>Para 2</p>" }
            result = subject.send(:sanitize_text, text)
            expect(result).to eq("Para 1\n\nPara 2")
          end

          it "truncates at 4000 characters by default" do
            text = { "en" => "A" * 5000 }
            result = subject.send(:sanitize_text, text)
            expect(result.length).to be <= 4000
          end

          it "truncates at custom length when specified" do
            text = { "en" => "A" * 100 }
            result = subject.send(:sanitize_text, text, 60)
            expect(result.length).to be <= 60
          end
        end

        describe "#force_welcome" do
          it "returns nil before start" do
            expect(subject.force_welcome).to be_nil
          end
        end

        describe "#resource_url" do
          context "with a Decidim::Participable resource" do
            let!(:participatory_process) { create(:participatory_process, organization:) }

            it "returns the resource locator URL" do
              url = subject.send(:resource_url, participatory_process)
              expect(url).to be_present
              expect(url).to include(participatory_process.slug)
            end
          end

          context "with an attachment that is attached" do
            let!(:participatory_process) { create(:participatory_process, organization:) }

            before do
              participatory_process.hero_image.attach(
                io: File.open(Decidim::Dev.asset("city.jpeg")),
                filename: "city.jpeg",
                content_type: "image/jpeg"
              )
            end

            it "returns a smaller variant URL when available" do
              original_url = participatory_process.attached_uploader(:hero_image).url
              url = subject.send(:resource_url, participatory_process.hero_image)
              expect(url).to be_present
              expect(url).not_to eq(original_url)
            end

            context "when uploader exposes a preferred variant" do
              let(:uploader) { double("Decidim::ApplicationUploader") }
              let(:variant_file) { instance_double("CarrierWave::SanitizedFile", size: 1024) }
              let(:variant_uploader) { instance_double("CarrierWave::Uploader", file: variant_file) }

              before do
                allow(participatory_process).to receive(:attached_uploader).with("hero_image").and_return(uploader)
                allow(uploader).to receive(:variants).and_return({ thumbnail: { resize_to_fit: [nil, 237] } })
                allow(uploader).to receive(:versions).and_return({ thumbnail: variant_uploader })
                allow(uploader).to receive(:url).with(variant: :thumbnail, host: "https://#{organization.host}").and_return("https://example.org/thumbnail.jpg")
              end

              it "uses the preferred variant URL" do
                url = subject.send(:resource_url, participatory_process.hero_image)
                expect(url).to eq("https://example.org/thumbnail.jpg")
              end
            end

            context "when no preferred variant is available and image exceeds WhatsApp max size" do
              let(:uploader) { instance_double("Decidim::ApplicationUploader") }

              before do
                allow(participatory_process.hero_image.blob).to receive(:byte_size).and_return(6 * 1024 * 1024)
                allow(participatory_process).to receive(:attached_uploader).with("hero_image").and_return(uploader)
                allow(uploader).to receive(:variants).and_return({})
                allow(uploader).to receive(:url).and_return("https://example.org/original.jpg")
              end

              it "returns false when fallback_image is false" do
                url = subject.send(:resource_url, participatory_process.hero_image)
                expect(url).to be false
              end

              it "returns fallback image when fallback_image is true" do
                url = subject.send(:resource_url, participatory_process.hero_image, fallback_image: true)
                expect(url).to include("chatbot-card-placeholder")
              end
            end
          end

          context "with an attachment that is not attached and fallback_image: true" do
            let!(:participatory_process) { create(:participatory_process, organization:) }

            before do
              participatory_process.hero_image.purge if participatory_process.hero_image.attached?
            end

            it "returns the fallback image URL" do
              url = subject.send(:resource_url, participatory_process.hero_image, fallback_image: true)
              expect(url).to include("chatbot-card-placeholder")
            end
          end

          context "with an attachment that is not attached and fallback_image: false" do
            let!(:participatory_process) { create(:participatory_process, organization:) }

            before do
              participatory_process.hero_image.purge if participatory_process.hero_image.attached?
            end

            it "returns false" do
              url = subject.send(:resource_url, participatory_process.hero_image, fallback_image: false)
              expect(url).to be false
            end
          end

          context "with nil resource" do
            it "returns false" do
              expect(subject.send(:resource_url, nil)).to be false
            end
          end
        end

        describe "#attachment_image_metadata" do
          it "uses blob byte_size for Decidim::Attachment file metadata" do
            blob = instance_double("ActiveStorage::Blob", content_type: "image/jpeg", byte_size: 1234)
            attachment_file = double("ActiveStorage::Attached::One", blob: blob)
            uploader = instance_double("Decidim::ApplicationUploader")
            attachment = Decidim::Attachment.allocate

            allow(attachment).to receive(:attached_uploader).with(:file).and_return(uploader)
            allow(attachment).to receive(:file).and_return(attachment_file)
            allow(attachment).to receive(:file_size).and_return(nil)

            metadata = subject.send(:attachment_image_metadata, attachment)

            expect(metadata).to eq([uploader, "image/jpeg", 1234])
          end
        end

        describe "#mark_as_read" do
          context "when message is acknowledgeable" do
            before do
              allow(received_message).to receive(:acknowledgeable?).and_return(true)
            end

            it "calls mark_as_read! on adapter" do
              subject.send(:mark_as_read)
              expect(adapter).to have_received(:mark_as_read!)
            end

            it "marks the message as read" do
              expect { subject.send(:mark_as_read) }.to change { message.reload.read_at }.from(nil)
            end
          end

          context "when message is not acknowledgeable" do
            before do
              allow(received_message).to receive(:acknowledgeable?).and_return(false)
            end

            it "does not call mark_as_read! on adapter" do
              subject.send(:mark_as_read)
              expect(adapter).not_to have_received(:mark_as_read!)
            end
          end

          context "when message is nil" do
            let(:message) { nil }
            let(:workflow) { described_class.new(adapter:, message: nil) }

            before do
              allow(received_message).to receive(:acknowledgeable?).and_return(true)
            end

            it "handles nil message gracefully" do
              expect { workflow.send(:mark_as_read) }.not_to raise_error
            end
          end
        end
      end
    end
  end
end
