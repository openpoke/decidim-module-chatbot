# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class ParticipatorySpaceWorkflow < BaseWorkflow
        def process_user_input
          send_welcome
        end

        def process_action_input
          case received_message.button_id
          when "start"
            # delegate_workflow(ParticipatorySpaceWorkflow)
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
              header_text: translated_attribute(participatory_space.title),
              body_text: strip_tags(translated_attribute(participatory_space.short_description)).truncate(200),
              buttons: [
                { id: "start", title: I18n.t("decidim.chatbot.workflows.participatory_space_workflow.buttons.participate") }
              ].tap do |buttons|
                buttons << { id: "end", title: I18n.t("decidim.chatbot.workflows.participatory_space_workflow.buttons.end") } unless parent_workflow.nil?
              end
            }
          )

          adapter.send!(message)
        end

        # TODO: obtain a participatory space based database configuration
        def participatory_space
          @participatory_space ||= organization.participatory_spaces.first
        end
      end
    end
  end
end
