module CustomMessageSettingsHelper
  def available_message_options(setting, lang, project_id=nil)
    options = [['', '']] +
                CustomMessageSetting.flatten_hash(MessageCustomize::Locale.available_messages(lang, project_id))
                .select{|_k, v| v.is_a?(String)}
                .map{|k, v| ["#{k}: #{v}", k]}

    options_for_select(options, disabled: setting.custom_messages_to_flatten_hash(lang, project_id).keys)
  end

  def normal_mode_input_fields(setting, lang, project_id=nil)
    return '' if setting.custom_messages(lang.to_s, false, project_id).is_a?(String) || setting.custom_messages(lang.to_s, false, project_id).blank?

    content = ActiveSupport::SafeBuffer.new
    custom_messages_hash = setting.custom_messages_to_flatten_hash(lang.to_s, project_id)
    custom_messages_hash.each do |k, v|
      content += content_tag(:p) do
        content_tag(:label, k) +
        text_field_tag("settings[custom_messages][#{k}]", v.to_s) +
        link_to_function('', '$(this).closest("p").remove();', class: 'icon icon-del clear-key-link')
      end
    end
    content
  end

  def open_default_messages_window_link(lang)
    link_to l(:label_default_messages),
            default_messages_custom_message_settings_path(lang: lang),
            class: 'icon icon-file text-plain',
            onclick: "window.open(this.href,'redmine_message_customize_plugin-default_messages', 'height=800, width=500');return false;",
            id: 'default-messages-link'
  end
end