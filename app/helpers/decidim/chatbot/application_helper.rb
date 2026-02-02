# frozen_string_literal: true

module Decidim
  module Chatbot
    module ApplicationHelper
      def participatory_space_options(organization)
        spaces = organization.public_participatory_spaces
        spaces.group_by { |s| s.class.model_name.human(count: 2) }
              .transform_values { |arr| arr.map { |s| [translated_attribute(s.title), s.to_gid.to_s] } }
      end

      def components_for_space(space_gid, organization, component_types: [])
        return [] if space_gid.blank?

        space = organization.public_participatory_spaces.find { |s| s.to_gid.to_s == space_gid }
        return [] unless space

        components = space.components.published
        components = components.where(manifest_name: component_types) if component_types.present?
        components.map do |c|
          { id: c.id.to_s, name: translated_attribute(c.name) }
        end
      end

      def components_for_space_json(organization, component_types: [])
        organization.public_participatory_spaces.each_with_object({}) do |space, hash|
          components = space.components.published
          components = components.where(manifest_name: component_types) if component_types.present?
          hash[space.to_gid.to_s] = components.map { |c| { id: c.id.to_s, name: translated_attribute(c.name) } }
        end.to_json
      end

      def delegate_workflow_options(exclude_workflow: nil)
        Decidim::Chatbot.start_workflows_registry.manifests
                        .reject { |m| m.name.to_s == exclude_workflow.to_s }
                        .map { |m| [m.title, m.name.to_s] }
      end
    end
  end
end
