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
          sender.current_workflow_merge!(page: current_page + 1, random_seed:)
        end

        def process_action_input
          case received_message.button_id
          when "more"
            process_user_input
          else
            mark_as_responding
            if commentable_id
              delegate_workflow(CommentsWorkflow, resource_gid: commentable_gid)
            else
              send_proposal_details
            end
          end
        end

        private

        def send_cards
          body = "*#{sanitize(component&.name)}*\n\n#{sanitize(component&.settings&.announcement)}"
          send_message!(
            type: :interactive_carousel,
            body_text: body,
            cards: current_proposals.map do |proposal|
              {
                id: proposal.id,
                title: I18n.t("decidim.chatbot.workflows.proposals.buttons.view_proposal"),
                body_text: sanitize(proposal.title).presence || I18n.t("decidim.chatbot.workflows.proposals.buttons.view_proposal"),
                image_url: resource_url(proposal.photo, fallback_image: true)
              }
            end
          )
        end

        def send_proposal_details
          return process_unprocessable_input unless proposal

          body = "*#{sanitize(proposal.title)}*\n\n#{sanitize(proposal.body)}\n\n#{resource_url(proposal)}"
          send_message!(
            type: :interactive_buttons,
            body_text: body,
            header_image: resource_url(proposal.photo),
            footer_text: proposal.creator_author&.presenter&.name,
            buttons: [
              {
                id: "comment-#{proposal.id}",
                title: I18n.t("decidim.chatbot.workflows.proposals.buttons.comment")
              }
            ]
          )
        end

        def send_continuation
          body = I18n.t("decidim.chatbot.workflows.proposals.remaining_proposals", count: remaining_proposals_count)
          send_message!(
            type: :interactive_buttons,
            body_text: body,
            buttons: [
              {
                id: "more",
                title: I18n.t("decidim.chatbot.workflows.proposals.buttons.more")
              },
              {
                id: "exit",
                title: I18n.t("decidim.chatbot.workflows.base.buttons.exit")
              }
            ]
          )
        end

        def send_ending
          send_message!(
            type: :interactive_buttons,
            body_text: I18n.t("decidim.chatbot.workflows.proposals.#{proposals.empty? ? "no_proposals" : "no_more_proposals"}"),
            buttons: [
              {
                id: "exit",
                title: I18n.t("decidim.chatbot.workflows.base.buttons.exit")
              }
            ]
          )
        end

        def component
          @component ||= Decidim::Component.find_by(id: config[:component_id])
        end

        def proposals
          @proposals ||= Decidim::Proposals::Proposal.where(component:).published.only_amendables
        end

        def commentable_id
          @commentable_id ||= received_message.button_id.to_s.start_with?("comment-") && received_message.button_id.to_s.sub("comment-", "")
        end

        def commentable_gid
          @commentable_gid ||= proposals.find_by(id: commentable_id)&.to_global_id
        end

        def proposal
          @proposal ||= proposals.find_by(id: received_message.button_id)
        end

        def current_proposals
          # Use deterministic ordering to keep pagination stable across requests.
          order_randomly(proposals, random_seed).page(current_page).per(per_page)
        end

        def remaining_proposals_count
          proposals.count - (per_page * current_page)
        end

        # Returns: A random float number between -1 and 1 to be used as a
        # random seed at the database.
        def random_seed
          @random_seed ||= options["random_seed"].presence || ((rand * 2) - 1).to_f
        end
      end
    end
  end
end
