# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class SimpleGreetingsWorkflow < BaseWorkflow
        def process_user_input
          send_greetings
        end

        def process_action_input
          CommentProposalsWorkflow.new(params).show_menu if received_message.button_id == "start"
        end

        private

        def send_greetings
          message = build_message(
            to: received_message.from,
            type: :interactive_buttons,
            data: {
              header_text: translated_attribute(organization.name),
              body_text: strip_tags(translated_attribute(organization.description)).truncate(200),
              buttons: [
                { id: "start", title: I18n.t("decidim.chatbot.workflows.simple_greetings_workflow.buttons.participate") }
              ]
            }
          )

          adapter.send!(message)
        end
      end
    end
  end
end
