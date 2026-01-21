# frozen_string_literal: true

module Decidim
  module Chatbot
    module Admin
      class SettingForm < Decidim::Form
        mimic :setting

        attribute :enabled, Boolean, default: false
        attribute :start_workflow, String
        attribute :participatory_space_gid, String
        attribute :component_id, Integer
        attribute :write_action, String

        validates :start_workflow, presence: true
        validates :participatory_space_gid, presence: true, if: :enabled?
        validates :component_id, presence: true, if: :enabled?
        validate :space_exists, if: -> { participatory_space_gid.present? }
        validate :component_belongs_to_space, if: -> { enabled? && participatory_space_gid.present? && component_id.present? }

        def map_model(model)
          self.enabled = model.enabled?
          self.start_workflow = model.start_workflow

          if model.participatory_space.present?
            self.participatory_space_gid = model.participatory_space.to_global_id.to_s
          end

          config = (model.config || {}).with_indifferent_access
          self.component_id = config[:component_id]
          self.write_action = config[:write_action]
        end

        def participatory_space
          return nil if participatory_space_gid.blank?

          @participatory_space ||= GlobalID::Locator.locate(participatory_space_gid)
        end

        def available_spaces
          spaces = []

          if defined?(Decidim::ParticipatoryProcess)
            Decidim::ParticipatoryProcess.where(organization: current_organization).published.each do |space|
              spaces << [translated_attribute(space.title), space.to_global_id.to_s]
            end
          end

          if defined?(Decidim::Assembly)
            Decidim::Assembly.where(organization: current_organization).published.each do |space|
              spaces << [translated_attribute(space.title), space.to_global_id.to_s]
            end
          end

          spaces
        end

        def available_workflows
          Decidim::Chatbot.start_workflows_registry.manifests.map do |manifest|
            [manifest.name.to_s.titleize, manifest.name.to_s]
          end
        end

        def workflow_display_name
          return "Workflow" if start_workflow.blank?

          start_workflow.to_s.sub(/_workflow$/, "").titleize
        end

        def available_components
          return [] if participatory_space.blank?

          participatory_space.components.published.map do |component|
            [translated_attribute(component.name), component.id]
          end
        end

        def available_actions_for_select
          return [] unless selected_component

          manifest = Decidim.find_component_manifest(selected_component.manifest_name)
          return [] unless manifest

          manifest.actions.map { |action| [action.to_s.humanize, action] }
        end

        def selected_component
          return nil unless participatory_space.present? && component_id.present?

          participatory_space.components.find_by(id: component_id)
        end

        def enabled?
          enabled == true
        end

        private

        def space_exists
          return if participatory_space.present?

          errors.add(:participatory_space_gid, :invalid)
        end

        def component_belongs_to_space
          return if participatory_space.blank?

          component = participatory_space.components.find_by(id: component_id)
          errors.add(:component_id, :invalid) if component.blank?
        end
      end
    end
  end
end
