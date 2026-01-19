# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class ParticipatorySpaceWorkflow < BaseWorkflow
        def process_user_input
          return adapter.send_message!(I18n.t("decidim.chatbot.workflows.participatory_space_workflow.no_spaces")) if participatory_space.nil?

          send_welcome
        end

        def process_action_input
          case received_message.button_id
          when "start"
            adapter.send_message!("Hang on! The participation process is not implemented yet.")
          when "end"
            reset_workflows
          end
        end

        private

        def send_welcome
          message = build_message(
            to: received_message.from,
            type: :interactive_buttons,
            data: {
              footer_text: translated_attribute(participatory_space.title),
              body_text: strip_tags(translated_attribute(participatory_space.short_description)).truncate(200),
              buttons: [
                { id: "start", title: I18n.t("decidim.chatbot.workflows.participatory_space_workflow.buttons.participate") }
              ].tap do |buttons|
                buttons << { id: "end", title: I18n.t("decidim.chatbot.workflows.participatory_space_workflow.buttons.end") } unless parent_workflow.nil?
              end
            }.tap do |data|
              data[:header_image] = participatory_space.attached_uploader(:hero_image).url if participatory_space.hero_image.attached?
            end
          )

          adapter.send!(message)
        end

        # TODO: obtain a participatory space based database configuration or passed parameters
        def participatory_space
          @participatory_space ||= organization.participatory_spaces.first
        end
      end
    end
  end
end
