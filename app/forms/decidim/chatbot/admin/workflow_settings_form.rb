# frozen_string_literal: true

module Decidim
  module Chatbot
    module Admin
      # Base class for workflow-specific settings forms.
      # Each workflow can define its own form class to provide
      # custom methods for the settings partial.
      class WorkflowSettingsForm
        include Decidim::TranslatableAttributes

        attr_reader :organization

        def initialize(organization)
          @organization = organization
        end

        def participatory_space_options
          spaces = organization.public_participatory_spaces
          spaces.group_by { |space| space.class.model_name.human(count: 2) }
                .transform_values { |grouped_spaces| grouped_spaces.map { |space| [translated_attribute(space.title), space.to_gid.to_s] } }
        end

        def components_for_space(space_gid)
          return [] if space_gid.blank?

          space = GlobalID::Locator.locate(space_gid)
          return [] unless space&.organization == organization

          filtered_components(space).map do |component|
            { id: component.id.to_s, name: translated_attribute(component.name), manifest_name: component.manifest_name }
          end
        end

        def components_for_space_json
          organization.public_participatory_spaces.each_with_object({}) do |space, hash|
            hash[space.to_gid.to_s] = filtered_components(space).map do |component|
              { id: component.id.to_s, name: translated_attribute(component.name), manifest_name: component.manifest_name }
            end
          end.to_json
        end

        protected

        def allowed_component_types
          nil
        end

        def filtered_components(space)
          components = space.components.published
          components = components.where(manifest_name: allowed_component_types) if allowed_component_types.present?
          components
        end
      end
    end
  end
end
