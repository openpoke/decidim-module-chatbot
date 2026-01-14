# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class OrganizationWelcomeWorkflow < BaseWorkflow
        def process_user_input
          send_welcome
        end

        def process_action_input
          case received_message.button_id
          when "start"
            delegate_workflow(ParticipatorySpaceWorkflow)
          when "end"
            exit_delegation
          end
        end

        private

        def send_welcome
          message = build_message(
            to: received_message.from,
            type: :interactive_buttons,
            data: {
              header_text: translated_attribute(organization.name),
              body_text: strip_tags(translated_attribute(organization.description)).truncate(200),
              buttons: [
                { id: "start", title: I18n.t("decidim.chatbot.workflows.organization_welcome_workflow.buttons.participate") }
              ].tap do |buttons|
                buttons << { id: "end", title: I18n.t("decidim.chatbot.workflows.organization_welcome_workflow.buttons.end") } unless parent_workflow.nil?
              end
            }
          )

          adapter.send!(message)
        end
      end
    end
  end
end
