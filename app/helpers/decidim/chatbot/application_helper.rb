# frozen_string_literal: true

module Decidim
  module Chatbot
    module ApplicationHelper
      def participatory_space_options(organization)
        spaces = organization.public_participatory_spaces
        spaces.group_by { |space| space.class.model_name.human(count: 2) }
              .transform_values { |grouped_spaces| grouped_spaces.map { |space| [translated_attribute(space.title), space.to_gid.to_s] } }
      end

      def components_for_space(space_gid, organization, component_types: [])
        return [] if space_gid.blank?

        space = GlobalID::Locator.locate(space_gid)
        return [] unless space&.organization == organization

        components = space.components.published
        components = components.where(manifest_name: component_types) if component_types.present?
        components.map do |component|
          { id: component.id.to_s, name: translated_attribute(component.name) }
        end
      end

      def components_for_space_json(organization, component_types: [])
        organization.public_participatory_spaces.each_with_object({}) do |space, hash|
          components = space.components.published
          components = components.where(manifest_name: component_types) if component_types.present?
          hash[space.to_gid.to_s] = components.map { |component| { id: component.id.to_s, name: translated_attribute(component.name) } }
        end.to_json
      end

      def delegate_workflow_options(exclude_workflow: nil)
        Decidim::Chatbot.start_workflows_registry.manifests
                        .reject { |manifest| manifest.name.to_s == exclude_workflow.to_s }
                        .map { |manifest| [manifest.title, manifest.name.to_s] }
      end
    end
  end
end
