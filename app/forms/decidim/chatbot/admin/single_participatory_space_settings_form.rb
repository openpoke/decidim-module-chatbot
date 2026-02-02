# frozen_string_literal: true

module Decidim
  module Chatbot
    module Admin
      # Form class for the single participatory space workflow settings.
      # Provides methods to filter components by proposals.
      class SingleParticipatorySpaceSettingsForm < WorkflowSettingsForm
        protected

        def allowed_component_types
          %w(proposals)
        end
      end
    end
  end
end
