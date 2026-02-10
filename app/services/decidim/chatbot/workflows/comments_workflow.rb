# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class CommentsWorkflow < BaseWorkflow
        def process_user_input
          return send_ending unless resource

          if force_welcome
            send_instructions
          else
            sender.current_workflow_merge!(comment: received_message.body)
            send_comment_confirmation
          end
        end

        def process_action_input
          return send_ending unless resource

          if received_message.button_id == "submit"
            mark_as_responding
            create_comment
            send_comment_created_message
          else
            exit_workflow
          end
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

        def send_comment_confirmation
          body = "*#{I18n.t("decidim.chatbot.workflows.comments.comment_received")}*\n\n#{received_message.body}"
          send_message!(
            type: :interactive_buttons,
            header_text: sanitize(resource.title, 60),
            body_text: body,
            buttons: [
              {
                id: "submit",
                title: I18n.t("decidim.chatbot.workflows.comments.buttons.submit")
              },
              {
                id: "exit",
                title: I18n.t("decidim.chatbot.workflows.comments.buttons.exit")
              },
              {
                id: "reset",
                title: I18n.t("decidim.chatbot.workflows.base.buttons.reset")
              }
            ]
          )
        end

        def create_comment
          resource.comments.create!(
            body: {
              sender.locale =>
              "#{comment_body}\n\n#{I18n.t("decidim.chatbot.workflows.comments.signature", provider: setting.provider.titleize)}"
            },
            author: sender.user,
            commentable: resource
          )
        end

        def send_comment_created_message
          body = "*#{I18n.t("decidim.chatbot.workflows.comments.comment_created")}*\n\n#{resource_url(resource)}#comments"
          send_message!(
            type: :interactive_buttons,
            header_text: sanitize(resource.title, 60),
            body_text: body,
            buttons: [
              {
                id: "reset",
                title: I18n.t("decidim.chatbot.workflows.base.buttons.reset")
              }
            ].tap do |buttons|
              buttons.unshift(options[:back_button]) if options[:back_button].present?
            end
          )
        end

        def comment_body
          sender.current_workflow_options["comment"]
        end

        def resource
          @resource ||= GlobalID::Locator.locate(options[:resource_gid])
        end
      end
    end
  end
end
