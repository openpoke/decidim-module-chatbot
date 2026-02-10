# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class CommentsWorkflow < BaseWorkflow
        def process_user_input
          return send_ending unless resource

          send_instructions
        end

        def process_action_input
          return send_ending unless resource

          send_message!("todo: process action input for comments workflow for resource #{resource.id}")
          exit_workflow
        end

        private

        def send_instructions
          send_message!(I18n.t("decidim.chatbot.workflows.comments.instructions", title: "*#{sanitize(resource.title)}*"))
        end

        def send_ending
          send_message!(
            type: :interactive_buttons,
            body_text: I18n.t("decidim.chatbot.workflows.comments.resource_not_found"),
            buttons: [
              {
                id: "exit",
                title: I18n.t("decidim.chatbot.workflows.base.buttons.exit")
              }
            ]
          )
        end

        def resource
          @resource ||= GlobalID::Locator.locate(options["resource_gid"])
        end
      end
    end
  end
end
