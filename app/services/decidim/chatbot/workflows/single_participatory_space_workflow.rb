# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class SingleParticipatorySpaceWorkflow < BaseWorkflow
        def process_user_input
          return adapter.send_message!(I18n.t("decidim.chatbot.workflows.single_participatory_space.not_configured")) unless setting.enabled?

          return adapter.send_message!(I18n.t("decidim.chatbot.workflows.single_participatory_space.no_spaces")) if participatory_space.nil?

          send_instructions_if_configured
          send_space_welcome
        end

        def process_action_input
          case received_message.button_id
          when "more_info"
            send_more_info
          when "participate"
            delegate_to_proposals_workflow
          when "exit"
            exit_workflow
          end
        end

        private

        def send_instructions_if_configured
          instructions = config[:instructions].presence
          return if instructions.blank?

          adapter.send_message!(instructions)
        end

        def send_space_welcome
          message = build_message(
            to: received_message.from,
            type: :interactive_buttons,
            data: {
              footer_text: translated_attribute(participatory_space.title),
              body_text: strip_tags(translated_attribute(participatory_space.short_description)).truncate(200),
              buttons: build_action_buttons
            }.tap do |data|
              data[:header_image] = participatory_space.attached_uploader(:hero_image).url if participatory_space.hero_image.attached?
            end
          )

          adapter.send!(message)
        end

        def build_action_buttons
          [
            { id: "more_info", title: I18n.t("decidim.chatbot.workflows.single_participatory_space_workflow.buttons.more_info") },
            { id: "participate", title: I18n.t("decidim.chatbot.workflows.single_participatory_space_workflow.buttons.participate") }
          ].tap do |buttons|
            buttons << { id: "end", title: I18n.t("decidim.chatbot.workflows.single_participatory_space_workflow.buttons.end") }
          end
        end

        def send_more_info
          description = translated_attribute(participatory_space.description)
          return adapter.send_message!(I18n.t("decidim.chatbot.workflows.single_participatory_space_workflow.no_description")) if description.blank?

          adapter.send_message!(strip_tags(description))
          # Resend the main welcome message for next action
          send_space_welcome
        end

        def delegate_to_proposals_workflow
          if proposals_workflow_class.present?
            delegate_workflow(proposals_workflow_class)
          else
            adapter.send_message!(I18n.t("decidim.chatbot.workflows.single_participatory_space_workflow.not_ready_yet"))
          end
        end

        def exit_workflow
          if parent_workflow.nil?
            reset_workflows
          else
            # Go back to parent workflow
            sender.update!(current_workflow_class: parent_workflow, parent_workflow_class: nil)
            parent_workflow_instance = parent_workflow.constantize.new(adapter:, message:)
            parent_workflow_instance.start(true)
          end
        end

        def participatory_space
          return @participatory_space if defined?(@participatory_space)

          @participatory_space = find_participatory_space
        end

        def component
          return @component if defined?(@component)

          @component = find_component
        end

        def proposals_workflow_class
          Decidim::Chatbot.start_workflows_registry.find(:proposals_workflow)&.workflow
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
