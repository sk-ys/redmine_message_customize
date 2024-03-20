class CustomMessageSetting < Setting
  validate :convertible_to_yaml,
           :custom_message_languages_are_available, :custom_message_keys_are_available

  def self.find_or_default
    super('plugin_redmine_message_customize')
  end

  def enabled?(project=nil)
    if project.present?
      init_project_settings(project)
      self.value[:project_settings][:"#{project.identifier}"][:enabled] != 'false'
    else
      self.value[:enabled] != 'false'
    end
  end

  def custom_messages(lang=nil, check_enabled=false, project=nil)
    return {} if check_enabled && !self.enabled?(project)

    if project.present?
      messages = raw_custom_messages_for_project(project, lang&.to_s)
    else
      messages = raw_custom_messages
    end

    messages = messages[lang.to_s] if lang.present?
    messages || {}
  end

  def custom_messages_with_timestamp(lang, project=nil)
    messages = self.custom_messages(lang, true, project)
    messages.merge({'redmine_message_customize_timestamp' => self.try(:updated_on).to_i.to_s})
  end

  def latest_messages_applied?(lang, project=nil)
    return true if self.new_record?

    # If project is specified, reload every time
    # TODO: Comparing timestamps
    return false if project.present?

    redmine_message_customize_timestamp = I18n.backend.send(:translations)[:"#{lang}"]&.[](:redmine_message_customize_timestamp)
    redmine_message_customize_timestamp == self.updated_on.to_i.to_s
  end

  def custom_messages_to_flatten_hash(lang=nil, project=nil)
    self.class.flatten_hash(custom_messages(lang, false, project))
  end

  def custom_messages_to_yaml(project=nil)
    messages = custom_messages(nil, false, project)
    if messages.is_a?(Hash)
      messages.present? ? YAML.dump(messages) : ''
    else
      raw_custom_messages
    end
  end

  def update_with_custom_messages(custom_messages, lang, project=nil)
    value = CustomMessageSetting.nested_hash(custom_messages)

    if project.present?
      save_custom_messages_for_project(value, lang, project)
    else
      original_custom_messages = self.custom_messages()
      messages =
        if value.present?
          original_custom_messages.merge({lang => value})
        else
          original_custom_messages.delete(lang)
          original_custom_messages
        end

      self.custom_messages = messages
      self.save
    end
  end

  def update_with_custom_messages_yaml(yaml, project=nil)
    if project.present?
      custom_messages = YAML.load(yaml)
      languages = custom_messages.keys
      languages.each do |lang|
        save_custom_messages_for_project(custom_messages[lang], lang, project)
      end
    else
      self.custom_messages = yaml
      self.save
    end
  end

  def toggle_enabled!(project=nil)
    init_project_settings(project) if project.present?

    self.transaction do
      if project.present?
        self.value = self.value.merge({
          project_settings: self.value[:project_settings].merge({:"#{project.identifier}" => {enabled: (!self.enabled?(project)).to_s}})
        })
      else
        self.value = self.value.merge({enabled: (!self.enabled?).to_s})
      end
      self.save
    end
  end

  # { date: { formats: { defaults: '%m/%d/%Y'}}} to {'date.formats.defaults' => '%m/%d/%Y'}
  def self.flatten_hash(hash=nil)
    return hash unless hash.is_a?(Hash)

    hash.each_with_object({}) do |(key, value), content|
      next self.flatten_hash(value).each do |k, v|
        content[:"#{key}.#{k}"] = v
      end if value.is_a? Hash
      content[key] = value
    end
  end

  # {'date.formats.defaults' => '%m/%d/%Y'} to { date: { formats: { defaults: '%m/%d/%Y'}}}
  def self.nested_hash(hash=nil)
    new_hash = {}
    hash.each do |key, value|
      h = value
      key.to_s.split('.').reverse_each do |k|
        h = {k => h}
      end
      new_hash = new_hash.deep_merge(h)
    end
    new_hash
  end

  def remove_project(project)
    paths = Dir.glob("#{projects_dir}/#{project.identifier}.*.yml")
    paths.each {|path| File.delete(path)}
  end

  private

  def projects_dir
    return @project_dir if @project_dir.present?

    p = Redmine::Plugin.find(:redmine_message_customize)
    @projects_dir = File.join(p.directory, 'config', 'locales', 'custom_messages', 'projects')
  end

  def raw_custom_messages
    self.value[:custom_messages] || self.value['custom_messages']
  end

  def raw_custom_messages_for_project(project, lang)
    custom_messages = {}
    return {} unless Dir.exist?(projects_dir)

    if lang.nil?
      MessageCustomize::Locale.available_locales.each do |locale|
        custom_messages = custom_messages.merge(raw_custom_messages_for_project(project, locale))
      end
    else
      locale_per_project_path = File.join(projects_dir, "#{project.identifier}.#{lang}.yml")
      self.transaction do
        if File.exist?(locale_per_project_path)
          custom_messages = open(locale_per_project_path, 'r') { |f| YAML.load(f) }
        end
      end
    end

    custom_messages || {}
  end

  def custom_messages=(messages)
    messages = YAML.load("#{messages}") unless messages.is_a?(Hash)
    self.value = self.value.merge({custom_messages: messages.presence || {}})
  rescue Psych::SyntaxError => e
    self.value = self.value.merge({custom_messages: messages})
  end

  def custom_message_keys_are_available
    return if errors.present?

    en_translation_hash = self.class.flatten_hash(MessageCustomize::Locale.available_messages('en'))
    custom_message_keys =
      custom_messages.values.each_with_object([]){|val, ar|
        ar.concat(self.class.flatten_hash(val).keys)
      }.uniq

    unused_keys = custom_message_keys.reject{|k| en_translation_hash.keys.include?(:"#{k}")}
    unusable_type_of_keys = (custom_message_keys - unused_keys).reject{|k| en_translation_hash[:"#{k}"].is_a?(String)}

    if unused_keys.present?
      errors.add(:base, "#{l(:error_unused_keys)} keys: [#{unused_keys.join(', ')}]")
    end
    if unusable_type_of_keys.present?
      errors.add(:base, "#{l(:error_unusable_type_of_keys)} keys: [#{unusable_type_of_keys.join(', ')}]")
    end
  end

  def custom_message_languages_are_available
    return if errors.present?

    unavailable_languages =
      custom_messages.keys.compact.reject do |language|
        MessageCustomize::Locale.available_locales.include?(language.to_sym)
      end
    if unavailable_languages.present?
      errors.add(:base, l(:error_unavailable_languages) + " [#{unavailable_languages.join(', ')}]")
    end
  end

  def convertible_to_yaml
    raw_messages = raw_custom_messages
    if raw_messages.present? && !raw_messages.is_a?(Hash)
      begin
        YAML.load("#{raw_messages}")
        errors.add(:base, l(:error_invalid_yaml_format))
      rescue Psych::SyntaxError => e
        errors.add(:base, "#{l(:error_invalid_yaml_format)} #{e.message}")
      end
    end
  end

  def save_custom_messages_for_project(value, lang, project)
    self.transaction do
      Dir.mkdir(projects_dir, 0664) unless Dir.exist?(projects_dir)
      locale_per_project_path = File.join(projects_dir, "#{project.identifier}.#{lang}.yml")

      if value.blank?
        File.delete(locale_per_project_path) if File.exist?(locale_per_project_path)
        return
      end

      custom_messages = {}
      custom_messages[lang] = value
      File.open(locale_per_project_path, 'w') { |f| YAML.dump(custom_messages, f) }
    end
  end

  def init_project_settings(project)
    if self.value[:project_settings].blank?
      self.transaction do
        self.value = self.value.merge({project_settings: {:"#{project.identifier}" => {enabled: true.to_s}}})
        self.save
      end
    end
    if self.value[:project_settings][:"#{project.identifier}"].blank?
      self.transaction do
        self.value = self.value.merge({project_settings: self.value[:project_settings].merge({:"#{project.identifier}" => {enabled: true.to_s}})})
        self.save
      end
    end
  end
end
