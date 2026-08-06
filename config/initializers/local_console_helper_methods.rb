return unless Rails.env.local?

Rails.application.config.to_prepare do
  unless Object.method_defined? :methods_named
    Object.define_method(:methods_named) do |candidate, sort: false|
      raise ArgumentError, "argument must be either a String or Symbol" unless candidate.is_a?(Symbol) || candidate.is_a?(String)

      collection = self.methods.select { it.to_s.include? candidate&.to_s }
      sort ? collection.sort : collection
    end
  end

  unless Object.method_defined? :uniq_method_names
    Object.define_method(:uniq_method_names) do |obj = self|
      obj.methods - Object.methods
    end
  end

  unless Object.method_defined? :uniq_methods_named
    Object.define_method(:uniq_methods_named) do |name = nil, sort: false|
      raise ArgumentError, "argument must be either a String or Symbol" unless name.nil? || name.is_a?(Symbol) || name.is_a?(String)

      names = self.uniq_method_names.map { it if name.nil? || name.to_s.in?(it.to_s) }.compact_blank
      debugger
      names ||= itself.uniq_method_names.map { it if name.nil? || name.to_s.in?(it.to_s) }.compact_blank
      sort ? names.sort : names
    end
  end
end

ActiveSupport.on_load(:active_record) do
  module CheckIfApplicationRecordSubklassesLoaded extend ActiveSupport::Concern
    included { class_attribute :subklasses_loaded, default: false }

    class_methods do
      def subklasses_loaded_min_amount = 5
      def determine_subklasses_loaded_value = self.subklasses_loaded = ActiveRecord::Base.connection.tables.map { it.classify.safe_constantize&.new }.compact.size >= subklasses_loaded_min_amount
      private :subklasses_loaded_min_amount
    end
  end

  include CheckIfApplicationRecordSubklassesLoaded
end

Rails.application.config.after_initialize do
  yield_self do path = "config/initializers/console_helper_methods.rb"  # block prints warning message on load + raises error if !Rails.env.local?
    output_gap = ->(amt = 0) { (amt.nil? || amt.zero?) ? nil : print("\n"*amt) }

    opening_output, closing_output = (" "*5 + "*"*20 + " "*5).then { [ it, it.reverse ] }
    output_gap.call(3).then { print( "#{opening_output}WARNING!#{closing_output}\n".colorize(:yellow) * 3 ) }
    puts( " "*5 + "# #{path}".colorize(:light_black) ).then { puts( (" "*5 + "DANGEROUS METHODS INCLUDED! SHOULD ONLY BE IN LOCAL ENV").colorize(:yellow) ) }.then { output_gap.call 3 }

    if msg = !Rails.env.local? && "raising error # => #{path}\nfile should only be loaded in local env"
      output_gap.call(5).then { Rails.logger.error msg }.then { puts msg.colorize(:red) }.then { output_gap.call(5) }.then { raise msg }
    end
  end

  module ConsoleHelperMethods
    Object.define_method(:methods_named) { |candidate, sort: false|
      raise ArgumentError, "argument must be either a String or Symbol" unless candidate.is_a?(Symbol) || candidate.is_a?(String)

      collection = self.methods.select { it.to_s.include? candidate&.to_s }
      sort ? collection.sort : collection
    } unless Object.method_defined? :methods_named

    def output_gap(amt = nil, gap: nil) = print "\n"*[ amt, gap ].compact_blank.then { |array| array.find { it.kind_of? Integer } || array.map { it if it.try(:to_s) }.first.to_i }

    def output_gap_with_string(string = "", amt = nil, return: false, gap: nil, times: 1, colorize: :white)
      gap_amt = gap || amt || (string.blank? ? 0 : 2)
      padding = gap_amt.round.then { it.even? ? it : it.next } / 2
      output_gap(padding).then { print "#{string}\n".colorize(colorize)* times if string.present? }.then { output_gap(padding) }

      binding.local_variable_get(:return).then do |return_value|
        case return_value
        when true, false, nil
          return_value ? string : nil
        else
          return_value
        end
      end
    end

    def output_sql(query, gap: 3, colorize: :magenta) = output_gap(gap).then { puts (query.kind_of?(String) ? query : query.to_sql).colorize(colorize.to_sym) }.then { output_gap(gap) }
    def output_pretty_json(val = nil, value: nil, return: false, gap: 3.0, colorize: :cyan)
      gap_amt = (gap/2).round(half: :down)
      gap = -> { output_gap gap_amt }
      return_keyword_value = binding.local_variable_get(:return)

      return_value = return_keyword_value.then { |obj|
        (obj == true) ? (value.presence || val.presence || {}) : obj
      } unless return_keyword_value == false

      val ||= value.presence || return_value
      json = JSON.parse val.kind_of?(String) ? val : val.to_json

      gap.call.then { puts JSON.pretty_generate(json).colorize(colorize.to_sym) }.then { gap.call }
      return_value
    end

    def association_reflections_by_macro_type(*args, **options)
      raise "missing model_name or array of ApplicationRecord subclasses" if args.flatten.empty?

      keys = Array.wrap(args).map { |element| (element.try(:model_name) || element.to_s.classify.constantize.model_name)&.element&.to_sym }

      macro_keys = %i[ belongs_to has_one has_many has_and_belongs_to_many ]
      valid_macros = options.symbolize_keys.select { it.in? macro_keys }.compact_blank.presence&.keys || macro_keys

      ActiveSupport::OrderedOptions.new.tap do |hash|
        reflections = keys.index_with do |key|
          model_class = key.to_s.classify.constantize
          model_class.reflect_on_all_associations.select { it.macro.in? valid_macros }.group_by(&:macro).transform_values { |assocs| assocs.map(&:name) }
        end

        nested_options = reflections.transform_values { ActiveSupport::OrderedOptions.new.update(**it) }
        hash.update **nested_options
      end
    end

    def active_record_table_classes(sort: true)
      ApplicationRecord.determine_subklasses_loaded_value unless ApplicationRecord.subklasses_loaded?
      ApplicationRecord.descendants.then { |descendants| sort ? descendants.sort_by { it&.model_name&.element } : descendants }
    end

    def active_record_table_names(sort: true)
      active_record_table_classes(sort: sort).map { it.model_name.plural }
    end

    def active_record_class_names(sort: true)
      active_record_table_classes(sort: sort).map { it.name }
    end

    def active_record_table_classes_count(sort: true)
      active_record_class_names(sort: sort).map(&:constantize).then do |array| hash = Hash.new
        array.each do |klass|
          key, value = klass.model_name.plural, klass.count
          hash[key.to_sym] = value

          hash.define_singleton_method("#{key}") { klass.all }
          hash.define_singleton_method("#{key.singularize}_model_class") { klass }
          hash.define_singleton_method("#{key.singularize}_count") { klass.count }
        end.then { hash }
      end
    end
  end

  include ConsoleHelperMethods
end
