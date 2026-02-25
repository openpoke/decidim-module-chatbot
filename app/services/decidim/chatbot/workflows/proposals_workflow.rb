# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class ProposalsWorkflow < BaseWorkflow
        def process_user_input
          return send_ending if current_proposals.empty? || (remaining_proposals_count + per_page).negative?

          mark_as_responding
          send_cards
          remaining_proposals_count <= 0 ? send_ending : send_continuation
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
              video = Decidim::Chatbot::Media::VideoEmbedExtractor.new(translated_attribute(proposal.body))
              {
                id: proposal.id,
                title: I18n.t("decidim.chatbot.workflows.proposals.buttons.view_proposal"),
                body_text: sanitize_text(proposal.title, 60).presence || I18n.t("decidim.chatbot.workflows.proposals.buttons.view_proposal"),
                image_url: video.thumbnail_url.presence || resource_url(proposal.photo, fallback_image: true)
              }
            end
          )
        end

        def send_proposal_details
          return process_unprocessable_input unless proposal

          # Check if proposal body contains a video iframe
          video = Decidim::Chatbot::Media::VideoEmbedExtractor.new(translated_attribute(proposal.body))

          # Build body text with video URL if present
          title_text = sanitize_text(proposal.title, 100)
          body_text = sanitize_text(proposal.body, calculate_max_body_length(video))
          proposal_url = resource_url(proposal)

          body = "*#{title_text}*\n\n"
          body += "🎥 #{video.url}\n\n" if video.valid?
          body += "#{body_text}\n\n#{proposal_url}"

          # Use video thumbnail as header image if available, otherwise use proposal photo
          header_image = video.thumbnail_url.presence || resource_url(proposal.photo)

          send_message!(
            type: :interactive_buttons,
            body_text: body,
            header_image:,
            footer_text: sanitize_text(proposal.creator_author&.presenter&.name, 60),
            buttons: [
              {
                id: "comment-#{proposal.id}",
                title: I18n.t("decidim.chatbot.workflows.proposals.buttons.comment")
              }
            ]
          )
        end

        # Calculate maximum body length dynamically to stay within 1024 char limit
        def calculate_max_body_length(video)
          # WhatsApp body text limit is 1024 characters
          total_limit = 1024

          # Calculate fixed overhead
          title_overhead = sanitize_text(proposal.title, 100).length + 6 # "*title*\n\n"
          video_overhead = video.valid? ? video.url.length + 6 : 0 # "🎥 url\n\n" (emoji is 2 bytes)
          proposal_url_overhead = resource_url(proposal).length + 2 # "\n\nurl"

          # Reserve space for newlines and formatting
          reserved_space = title_overhead + video_overhead + proposal_url_overhead

          # Return available space for body text, with minimum of 100 chars
          [total_limit - reserved_space, 100].max
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
          @proposals ||= begin
            proposal_search = Decidim::Proposals::Proposal.where(component:).published.only_amendables
            proposal_search.where.not(proposal_state: rejected_states).or(proposal_search.where(proposal_state: nil))
          end
        end

        def rejected_states
          @rejected_states ||= Decidim::Proposals::ProposalState.where(component:, token: :rejected).select(:id)
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
