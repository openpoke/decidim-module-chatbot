# frozen_string_literal: true

module Decidim
  module Chatbot
    # Custom helpers, scoped to the Chatbot engine.
    #
    module ApplicationHelper
      # Returns participatory spaces grouped by manifest type for optgroup select.
      # Output format: { "Processes" => [["Space title", "gid://..."]], "Assemblies" => [...] }
      def grouped_participatory_spaces_for_select(organization)
        grouped = {}

        Decidim.participatory_space_manifests.each do |manifest|
          spaces = manifest.participatory_spaces.call(organization)
          next if spaces.blank?

          label = manifest.model_class_name.constantize.model_name.human(count: 2)
          grouped[label] = spaces.map { |space| [translated_attribute(space.title), space.to_gid.to_s] }
        end

        grouped
      end

      # Returns published proposal components for a given space GID.
      # Only proposals for the moment
      def proposal_components_for_select(space_gid)
        return [] if space_gid.blank?

        space = GlobalID::Locator.locate(space_gid)
        return [] unless space

        space.components.published.where(manifest_name: "proposals").map do |component|
          [translated_attribute(component.name), component.id.to_s]
        end
      end

      # Returns workflows available for delegation (excludes the given workflow).
      def delegate_workflows_for_select(exclude_workflow: nil)
        Decidim::Chatbot.start_workflows_registry.manifests
                        .reject { |m| m.name.to_s == exclude_workflow.to_s }
                        .map { |m| [m.title, m.name.to_s] }
      end
    end
  end
end
