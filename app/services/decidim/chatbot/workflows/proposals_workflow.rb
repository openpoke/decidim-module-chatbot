# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class ProposalsWorkflow < BaseWorkflow
        def process_user_input
          return send_ending if current_proposals.empty? || remaining_proposals_count.negative?

          mark_as_responding
          send_cards
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
              delegate_workflow(
                Decidim::Chatbot::Workflows::CommentsWorkflow,
                resource_gid: commentable_gid.to_s,
                back_button: { id: "more", title: I18n.t("decidim.chatbot.workflows.proposals.buttons.more") }
              )
            else
              send_proposal_details
            end
          end
        end

        private

        def send_cards
          body = "*#{sanitize_text(component&.name, 200)}*\n\n#{sanitize_text(component&.settings&.announcement, 800)}"
          send_message!(
            type: :interactive_carousel,
            body_text: body,
            cards: current_proposals.map do |proposal|
              {
                id: proposal.id,
                title: I18n.t("decidim.chatbot.workflows.proposals.buttons.view_proposal"),
                body_text: sanitize_text(proposal.title, 60).presence || I18n.t("decidim.chatbot.workflows.proposals.buttons.view_proposal"),
                image_url: resource_url(proposal.photo, fallback_image: true)
              }
            end
          )
        end

        def send_proposal_details
          return process_unprocessable_input unless proposal

          body = "*#{sanitize_text(proposal.title, 100)}*\n\n#{sanitize_text(proposal.body, 800)}\n\n#{resource_url(proposal)}"
          send_message!(
            type: :interactive_buttons,
            body_text: body,
            header_image: resource_url(proposal.photo),
            footer_text: sanitize_text(proposal.creator_author&.presenter&.name, 60),
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
            delay: 6,
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
            delay: 6,
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
          proposals_seach= Decidim::Proposals::Proposal.where(decidim_component_id: component.id).published.only_amendables
          proposals_seach.where(proposal_state: none_rejected).or(proposals_seach.where(proposal_state: nil))

        end

        def none_rejected
          Decidim::Proposals::ProposalState.where.not(decidim_component_id: component.id, token: "rejected")
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
