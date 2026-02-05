# frozen_string_literal: true

module Decidim
  module Chatbot
    module Admin
      # Form class for the single participatory space workflow settings.
      # Extends SettingForm and adds participatory space selection attributes.
      class SingleParticipatorySpaceSettingsForm < SettingForm
        mimic :setting

        attribute :participatory_space_gid, String
        attribute :component_id, String
        attribute :instructions, String

        validates :participatory_space_gid, presence: true, if: :enabled?
        validates :component_id, presence: true, if: :enabled?

        def map_model(model)
          super
          self.participatory_space_gid = config[:participatory_space_gid]
          self.component_id = config[:component_id]&.to_s
          self.instructions = config[:instructions]
        end

        # Returns the workflow-specific config hash for saving
        def workflow_config
          {
            participatory_space_gid: participatory_space_gid,
            component_id: component_id,
            instructions: instructions
          }.compact_blank
        end

        def participatory_space_options
          spaces = current_organization.public_participatory_spaces
          spaces.group_by { |space| space.class.model_name.human(count: 2) }
                .transform_values { |grouped| grouped.map { |space| [translated_attribute(space.title), space.to_gid.to_s] } }
        end

        def component_options
          components_for_space(participatory_space_gid)
        end

        def components_for_space(space_gid)
          return [] if space_gid.blank?

          space = GlobalID::Locator.locate(space_gid)
          return [] unless space&.organization == current_organization

          space.components.published.where(manifest_name: allowed_component_types).map do |component|
            [translated_attribute(component.name), component.id.to_s]
          end
        end

        def components_json
          current_organization.public_participatory_spaces.each_with_object({}) do |space, hash|
            hash[space.to_gid.to_s] = space.components.published.where(manifest_name: allowed_component_types).map do |component|
              { id: component.id.to_s, name: translated_attribute(component.name) }
            end
          end.to_json
        end

        private

        def allowed_component_types
          %w(proposals)
        end
      end
    end
  end
end
