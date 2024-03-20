require_dependency 'projects_helper'

module MessageCustomize
  module ProjectsHelperPatch
    include CustomMessageSettingsHelper

    def project_settings_tabs
      tabs = super

      return tabs if Setting["plugin_redmine_message_customize"][:enabled_per_project] != "1"
      return tabs if @project.enabled_modules.where(name: "redmine_message_customize").blank?
      return tabs unless User.current.allowed_to?(:customize_project_messages, @project)

      @setting = CustomMessageSetting.find_or_default
      @lang = User.current.language.presence || Setting.default_language

      tabs << {
        name: 'message_customize',
        partial: '/custom_message_settings/form',
        label: :label_custom_messages,
        onclick:
          "if ($('#tab-content-message_customize .tab-content:visible').length === 0) {" +
          "  showTab('message_customize', this.href); showTab('normal', this.href);" +
          "}"
      }

      tabs
    end
  end
end

ProjectsController.send :helper, MessageCustomize::ProjectsHelperPatch
