Rails.application.config.to_prepare do
  unless Object.method_defined? :uniq_method_names
    Object.define_method(:uniq_method_names) do |obj = self|
      obj.methods - Object.methods
    end
  end

  unless Object.method_defined? :uniq_methods_named
    Object.define_method(:uniq_methods_named) do |name = nil, sort: false|
      raise ArgumentError, "argument must be either a String or Symbol" unless name.nil? || name.is_a?(Symbol) || name.is_a?(String)

      names = itself.uniq_method_names.map { it if name.nil? || name.to_s.in?(it.to_s) }.compact_blank
      sort ? names.sort : names
    end
  end
end

return unless Rails.env.local?

Rails.application.config.after_initialize do
  def output_schema_table_model_names = (ActiveRecord::Base.connection.tables - %w[schema_migrations]).map { it unless it.classify.safe_constantize.nil? }.compact_blank
  def output_all_active_record_classes = output_schema_table_model_names.map { klass = it.classify.safe_constantize }.compact_blank
  def output_all_active_records(sort: true) = (array = output_all_active_record_classes.map { it.name }; (sort ? array.sort : array).index_with { it.constantize.count }.with_indifferent_access)

  def output_sql(query, gap: 3, colorize: "white") = (str = (query.kind_of?(String) ? query : query.to_sql).colorize(colorize.to_sym); puts "\n"*gap; puts str; puts "\n"*gap)
  def output_pretty_json(value, gap: 0, colorize: :green, return_value: false) = output_gap(gap).then { puts JSON.pretty_generate(JSON.parse(value.kind_of?(String) ? value : value.to_json)).colorize(colorize.to_sym) }.then { output_gap(gap) }.then { return_value ? value : nil }
  def output_gap(amt = 3) = (puts "\n"*amt)

  def time_humanized_format(time, time_zone_name: "Eastern Time (US & Canada)", format: "%m/%d/%Y %I:%M:%S %p")
    time.in_time_zone(time_zone_name).strftime(format)
  end

  def fake_next_company_name = (name = "company"; name.concat " #{Company.last&.id + 1}" unless Company.none?; name)

  def fake_person_name(first_name: Faker::Name.first_name, last_name: Faker::Name.last_name) = NameOfPerson::PersonName.full("#{first_name} #{last_name}")
  def fake_person_title = (title = Faker::Job.title; [ true, false ].sample ? title : "#{Faker::Job.seniority} #{title}")

  def fake_next_user_email_address = "email#{(User.last&.id || 1) + 1}@example.com"

  def fake_next_user_attributes(name: fake_person_name, role: "administrator", email_address: fake_next_user_email_address, password: "123456")
    { name: name, role: role, email_address: email_address, password: password }
  end

  def fake_create_user!(name: fake_person_name, email_address: fake_next_user_email_address, password: "123456")
    user = User.create role: role, name: name, email_address: email_address, password: password
    user.skip_confirmation_notification! && user.save! && user
  end
end
