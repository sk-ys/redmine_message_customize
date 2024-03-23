# frozen_string_literal: true

require File.expand_path('../lib/message_customize/locale', __FILE__)
require File.expand_path('../lib/message_customize/hooks', __FILE__)
require File.expand_path('../lib/message_customize/application_controller_patch', __FILE__)
require File.expand_path('../lib/message_customize/projects_helper_patch', __FILE__)
require File.expand_path('../lib/message_customize/project_patch', __FILE__)
require File.expand_path('../lib/message_customize/settings_controller_patch', __FILE__)

p = Redmine::Plugin.register :redmine_message_customize do
  name 'Redmine message customize plugin'
  version '1.0.0'
  description 'This is a plugin that allows messages in Redmine to be overwritten from the admin view'
  author 'Far End Technologies Corporation'
  url 'https://github.com/farend/redmine_message_customize'
  author_url 'https://github.com/farend'
  settings default: {
    custom_messages: {},
    enabled: 'true',
    project_settings: {},
    enabled_per_project: '0',
    active_project: nil
  }, partial: 'custom_message_settings/settings'
  menu :admin_menu, :custom_messages, { controller: 'custom_message_settings', action: 'edit' },
         caption: :label_custom_messages, html: { class: 'icon icon-edit' }
  requires_redmine version_or_higher: '3.2'
  project_module :redmine_message_customize do
    permission :customize_project_messages, custom_message_settings: :update
  end
end

Rails.application.config.i18n.load_path += Dir.glob(File.join(p.directory, 'config', 'locales', 'custom_messages', '*.rb'))
