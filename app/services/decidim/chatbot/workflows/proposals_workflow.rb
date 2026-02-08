# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class ProposalsWorkflow < BaseWorkflow
        def process_user_input
          return send_ending if current_proposals.empty? || remaining_proposals_count.negative?

          mark_as_responding
          send_cards
          sleep(1) # Sleep for a short time to ensure the user receives the first message before the continuation
          remaining_proposals_count <= per_page ? send_ending : send_continuation
          sender.current_workflow_options!(sender.current_workflow_options.merge(page: current_page + 1))
        end

        def process_action_input
          case received_message.button_id
          when "more"
            process_user_input
          when "end"
            exit_workflow
          else
            mark_as_responding
            # TODO: show proposal details
          end
        end

        private

        def send_cards
          message = build_message(
            to: received_message.from,
            type: :interactive_carousel,
            data: {
              body_text: body,
              cards: current_proposals.map do |proposal|
                {
                  id: proposal.id,
                  title: I18n.t("decidim.chatbot.workflows.proposals.buttons.view_proposal"),
                  body_text: sanitize(proposal.title).presence || I18n.t("decidim.chatbot.workflows.proposals.buttons.view_proposal"),
                  image_url: proposal.photo&.attached? ? proposal.photo.attached_uploader(:file).url : image_url("media/images/chatbot-card-placeholder.png")
                }
              end
            }
          )
          adapter.send!(message)
        end

        def send_continuation
          body = I18n.t("decidim.chatbot.workflows.proposals.remaining_proposals", count: remaining_proposals_count)
          message = build_message(
            to: received_message.from,
            type: :interactive_buttons,
            data: {
              body_text: body,
              buttons: [
                {
                  id: "more",
                  title: I18n.t("decidim.chatbot.workflows.proposals.buttons.more")
                },
                {
                  id: "end",
                  title: I18n.t("decidim.chatbot.workflows.proposals.buttons.end")
                }
              ]
            }
          )
          adapter.send!(message)
        end

        def send_ending
          message = build_message(
            to: received_message.from,
            type: :interactive_buttons,
            data: {
              body_text: I18n.t("decidim.chatbot.workflows.proposals.#{proposals.empty? ? "no_proposals" : "no_more_proposals"}"),
              buttons: [
                {
                  id: "end",
                  title: I18n.t("decidim.chatbot.workflows.proposals.buttons.end")
                }
              ]
            }
          )
          adapter.send!(message)
        end

        def body
          announcement = sanitize(component&.settings&.announcement)
          "*#{sanitize(component.name)}*\n\n#{announcement}"
        end

        def component
          @component ||= Decidim::Component.find_by(id: config[:component_id])
        end

        def proposals
          @proposals ||= Decidim::Proposals::Proposal.where(component:).published
        end

        def current_page
          config[:page].to_i.positive? ? config[:page].to_i : 1
        end

        def current_proposals
          proposals.page(current_page).per(per_page)
        end

        def remaining_proposals_count
          proposals.count - (per_page * current_page)
        end

        def per_page
          10
        end
      end
    end
  end
end
