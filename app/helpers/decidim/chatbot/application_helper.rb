# frozen_string_literal: true

module Decidim
  module Chatbot
    module ApplicationHelper
      # Returns workflow options for select dropdown.
      # Excludes specified workflow to prevent circular delegation.
      def delegate_workflow_options(exclude_workflow: nil)
        Decidim::Chatbot.start_workflows_registry.manifests
                        .reject { |manifest| manifest.name.to_s == exclude_workflow.to_s }
                        .map { |manifest| [manifest.title, manifest.name.to_s] }
      end
    end
  end
end
