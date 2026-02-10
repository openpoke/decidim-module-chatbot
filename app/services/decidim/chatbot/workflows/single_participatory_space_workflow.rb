# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class SingleParticipatorySpaceWorkflow < BaseWorkflow
        def process_user_input
          return send_message!(I18n.t("decidim.chatbot.workflows.single_participatory_space.no_spaces")) if participatory_space.nil?

          send_instructions_if_configured
          send_space_welcome
        end

        def process_action_input
          case received_message.button_id
          when "more_info"
            send_more_info
          when "participate"
            delegate_to_proposals_workflow
          else
            send_space_welcome # Re-send welcome message with action buttons if unrecognized action, to guide the user
          end
        end

        private

        def send_instructions_if_configured
          instructions = config[:instructions].presence
          return if instructions.blank?

          send_message!(instructions)
        end

        def send_space_welcome
          send_message!(
            {
              type: :interactive_buttons,
              body_text: sanitize(participatory_space.short_description).truncate(200).to_s,
              footer_text: sanitize(participatory_space.title),
              buttons: build_action_buttons
            }.tap do |data|
              data[:header_image] = resource_url(participatory_space&.hero_image)
            end
          )
        end

        def build_action_buttons
          [
            { id: "more_info", title: I18n.t("decidim.chatbot.workflows.single_participatory_space.buttons.more_info") },
            { id: "participate", title: I18n.t("decidim.chatbot.workflows.single_participatory_space.buttons.participate") }
          ].tap do |buttons|
            buttons << { id: "exit", title: I18n.t("decidim.chatbot.workflows.base.buttons.exit") } if parent_workflow.present?
          end
        end

        def send_more_info
          description = sanitize(participatory_space.description).presence || sanitize(participatory_space.short_description)
          body = "*#{sanitize(participatory_space.title)}*\n\n#{description}\n\n#{resource_url(participatory_space)}"
          send_message!(
            {
              body: body,
              preview_url: true
            }
          )
        end

        def delegate_to_proposals_workflow
          if component.present? && component.manifest_name == "proposals"
            delegate_workflow(Decidim::Chatbot::Workflows::ProposalsWorkflow, component_id: component.id)
          else
            send_message!(I18n.t("decidim.chatbot.workflows.single_participatory_space.not_ready_yet"))
          end
        end

        def participatory_space
          @participatory_space ||= GlobalID::Locator.locate(config[:participatory_space_gid])
        rescue ActiveRecord::RecordNotFound
          nil
        end

        def component
          @component ||= participatory_space&.components&.find_by(id: config[:component_id])
        end
      end
    end
  end
end
