# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class ParticipatorySpaceWorkflow < BaseWorkflow
        def process_user_input
          return adapter.send_message!(I18n.t("decidim.chatbot.workflows.participatory_space_workflow.not_configured")) unless setting.enabled?

          return adapter.send_message!(I18n.t("decidim.chatbot.workflows.participatory_space_workflow.no_spaces")) if participatory_space.nil?

          send_welcome
        end

        def process_action_input
          case received_message.button_id
          when "start"
            # TODO: Temporary stub. Shows a message with "Participate" button.
            # Future: This could show more details about the component or available actions.
            send_participate_prompt
          when "participate"
            # TODO: Temporary stub. Replace with actual implementation.
            # Future: Start a conversation flow to collect proposal data from user.
            if can_write?
              handle_write_action
            else
              adapter.send_message!(I18n.t("decidim.chatbot.workflows.participatory_space_workflow.read_only_mode"))
            end
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
                { id: "start", title: I18n.t("decidim.chatbot.workflows.participatory_space_workflow.buttons.start") }
              ].tap do |buttons|
                buttons << { id: "end", title: I18n.t("decidim.chatbot.workflows.participatory_space_workflow.buttons.end") } unless parent_workflow.nil?
              end
            }.tap do |data|
              data[:header_image] = participatory_space.attached_uploader(:hero_image).url if participatory_space.hero_image.attached?
            end
          )

          adapter.send!(message)
        end

        # TODO: Temporary stub. Shows component info and "Participate" button.
        # Future: Could show available actions, component description, etc.
        def send_participate_prompt
          message = build_message(
            to: received_message.from,
            type: :interactive_buttons,
            data: {
              body_text: I18n.t("decidim.chatbot.workflows.participatory_space_workflow.participate_prompt"),
              buttons: [
                { id: "participate", title: I18n.t("decidim.chatbot.workflows.participatory_space_workflow.buttons.participate") },
                { id: "end", title: I18n.t("decidim.chatbot.workflows.participatory_space_workflow.buttons.end") }
              ]
            }
          )

          adapter.send!(message)
        end

        def participatory_space
          @participatory_space ||= setting.participatory_space
        end

        def component
          @component ||= setting.selected_component
        end

        # TODO: Temporary implementation. Checks if admin configured a write action.
        # Future: May need more granular permission checks (user authorization, component settings, etc.)
        def can_write?
          setting.write_action.present?
        end

        # TODO: Temporary stub. Currently just shows "coming soon" message.
        # Future: Replace with WriteAction classes that handle conversation flow
        # to collect data from user and create resources (proposals, comments, etc.)
        def handle_write_action
          case setting.write_action
          when "create_proposal"
            adapter.send_message!(I18n.t("decidim.chatbot.workflows.participatory_space_workflow.write_actions.coming_soon"))
          else
            adapter.send_message!(I18n.t("decidim.chatbot.workflows.participatory_space_workflow.write_actions.unknown_action"))
          end
        end
      end
    end
  end
end
