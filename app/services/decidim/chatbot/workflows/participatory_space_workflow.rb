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
            adapter.send_message!(I18n.t("decidim.chatbot.workflows.participatory_space_workflow.read_only_mode"))
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
          return @participatory_space if defined?(@participatory_space)

          @participatory_space = find_participatory_space
        end

        def component
          return @component if defined?(@component)

          @component = find_component
        end

        def find_participatory_space
          gid = config[:participatory_space_gid]
          return nil if gid.blank?

          GlobalID::Locator.locate(gid)
        rescue ActiveRecord::RecordNotFound
          nil
        end

        def find_component
          return nil unless participatory_space && config[:component_id].present?

          participatory_space.components.find_by(id: config[:component_id])
        end

        def config
          @config ||= (setting.config || {}).with_indifferent_access
        end
      end
    end
  end
end
