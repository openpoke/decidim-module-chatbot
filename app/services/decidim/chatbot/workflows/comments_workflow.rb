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
            sender.current_workflow_merge!(comment: received_message.body.to_s.truncate(4000))
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
          send_message!(I18n.t("decidim.chatbot.workflows.comments.instructions", title: "*#{sanitize_text(resource.title)}*"))
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
          body = sanitize_text("*#{I18n.t("decidim.chatbot.workflows.comments.comment_received")}*\n\n#{received_message.body.truncate(comments_max_length)}")
          send_message!(
            type: :interactive_buttons,
            header_text: sanitize_text(resource.title, 60),
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
              sender.locale => comment_body
            },
            author: sender.user,
            commentable: resource
          )
        end

        def send_comment_created_message
          body = "*#{I18n.t("decidim.chatbot.workflows.comments.comment_created")}*\n\n#{resource_url(resource)}#comments"
          send_message!(
            type: :interactive_buttons,
            header_text: sanitize_text(resource.title, 60),
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
          original = sender.current_workflow_options["comment"].to_s.truncate(comments_max_length)
          "#{original}#{signature}"
        end

        def resource
          @resource ||= GlobalID::Locator.locate(options[:resource_gid])
        rescue ActiveRecord::RecordNotFound
          nil
        end

        def signature
          "\n\n#{I18n.t("decidim.chatbot.workflows.comments.signature", provider: setting.provider.titleize)}"
        end

        # note that this is copied from the CommentFormCell, but we want to make sure that the same limits are applied when users comment through the chatbot
        def comments_max_length
          hard_max_length = 1000

          length = if resource.respond_to?(:component)
                     if resource.component.settings.comments_max_length.to_i.positive?
                       resource.component.settings.comments_max_length
                     elsif organization.comments_max_length.to_i.positive?
                       organization.comments_max_length
                     else
                       hard_max_length
                     end
                   else
                     hard_max_length
                  end
          length - signature.length
        end
      end
    end
  end
end
