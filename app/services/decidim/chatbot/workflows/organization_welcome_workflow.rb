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
            delegate_to_configured_workflow
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
              header_text: translated_attribute(organization.name),
              body_text: welcome_body_text,
              buttons: welcome_buttons
            }
          )

          adapter.send!(message)
        end

        def welcome_body_text
          config[:custom_text].presence || decidim_sanitize(translated_attribute(organization.description), strip_tags: true)
        end

        def welcome_buttons
          buttons = [
            { id: "start", title: I18n.t("decidim.chatbot.workflows.organization_welcome_workflow.buttons.participate") }
          ]
          buttons << { id: "end", title: I18n.t("decidim.chatbot.workflows.organization_welcome_workflow.buttons.end") } unless parent_workflow.nil?
          buttons
        end

        def delegate_to_configured_workflow
          target_workflow_name = config[:delegate_workflow]
          if target_workflow_name.present?
            target_manifest = Decidim::Chatbot.start_workflows_registry.find(target_workflow_name)
            if target_manifest&.workflow
              delegate_workflow(target_manifest.workflow)
              return
            end
          end

          # Fallback: delegate to ParticipatorySpaceWorkflow (backward compatibility)
          delegate_workflow(ParticipatorySpaceWorkflow)
        end

        def config
          @config ||= (setting.config || {}).with_indifferent_access
        end
      end
    end
  end
end
