# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class MeetingsWorkflow < BaseWorkflow
        def process_user_input
          carousel = build_message(
            to: received_message.from,
            type: :interactive_carousel,
            data: {
              body_text: I18n.t("decidim.chatbot.workflows.meetings_workflow.latest_meetings"),
              cards: meetings.map do |meeting|
                {
                  image_url: ActionController::Base.helpers.asset_pack_url("media/images/meetings.png", host: "https://#{organization.host}"),
                  body_text: strip_tags(translated_attribute(meeting.description)).truncate(100),
                  url_title: translated_attribute(meeting.title),
                  url: Decidim::ResourceLocatorPresenter.new(meeting).url
                }
              end
            }
          )
          adapter.send!(carousel)
          parent_workflow&.clear_delegated_workflow
        end

        private

        def meetings
          # Todo order by the nearest meeting date
          Decidim::Meetings::Meeting.where(component: meeting_components).published.not_hidden.limit(10)
        end

        def meeting_components
          @meeting_components ||= Decidim::Component
                                  .where(manifest_name: "meetings")
                                  .where(participatory_space: participatory_spaces)
                                  .published
        end

        def participatory_spaces
          @participatory_spaces ||= organization.public_participatory_spaces
        end
      end
    end
  end
end
