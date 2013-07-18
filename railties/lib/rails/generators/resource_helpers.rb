require 'rails/generators/active_model'

module Rails
  module Generators
    # Deal with controller names on scaffold and add some helpers to deal with
    # ActiveModel.
    module ResourceHelpers # :nodoc:
      mattr_accessor :skip_warn

      def self.included(base) #:nodoc:
        base.class_option :force_plural, type: :boolean, desc: "Forces the use of a plural ModelName"
        base.class_option :model_name, type: :string, desc: "ModelName to be used"
      end

      # Set controller variables on initialization.
      def initialize(*args) #:nodoc:
        super
        if options[:model_name]
          controller_name = name
          self.name = options[:model_name]
          assign_names!(self.name)
        else
          controller_name = name
        end

        if name == name.pluralize && name.singularize != name.pluralize && !options[:force_plural]
          unless ResourceHelpers.skip_warn
            say "Plural version of the model detected, using singularized version. Override with --force-plural."
            ResourceHelpers.skip_warn = true
          end
          name.replace name.singularize
          assign_names!(name)
        end

        assign_controller_names!(controller_name.pluralize)
      end

      protected

        attr_reader :controller_name, :controller_file_name

        def controller_class_path
          if options[:model_name]
            @controller_class_path
          else
            class_path
          end
        end

        def assign_controller_names!(name)
          @controller_name = name
          @controller_class_path = name.include?('/') ? name.split('/') : name.split('::')
          @controller_class_path.map! { |m| m.underscore }
          @controller_file_name = @controller_class_path.pop
        end

        def controller_file_path
          @controller_file_path ||= (controller_class_path + [controller_file_name]).join('/')
        end

        def controller_class_name
          (controller_class_path + [controller_file_name]).map!{ |m| m.camelize }.join('::')
        end

        def controller_i18n_scope
          @controller_i18n_scope ||= controller_file_path.tr('/', '.')
        end

        # Loads the ORM::Generators::ActiveModel class. This class is responsible
        # to tell scaffold entities how to generate an specific method for the
        # ORM. Check Rails::Generators::ActiveModel for more information.
        def orm_class
          @orm_class ||= begin
            # Raise an error if the class_option :orm was not defined.
            unless self.class.class_options[:orm]
              raise "You need to have :orm as class option to invoke orm_class and orm_instance"
            end

            begin
              "#{options[:orm].to_s.camelize}::Generators::ActiveModel".constantize
            rescue NameError
              Rails::Generators::ActiveModel
            end
          end
        end

        # Initialize ORM::Generators::ActiveModel to access instance methods.
        def orm_instance(name=singular_table_name)
          @orm_instance ||= orm_class.new(name)
        end

        def namespaced_variable_name(name, prefix='')
          if controller_class_path.present?
            names = controller_class_path.map{|path| ':' + path } << prefix + singular_table_name
            "[" + names.join(', ') + "]"
          else
            prefix + singular_table_name
          end
        end

        def namespaced_ivar_name(name)
          namespaced_variable_name(name, '@')
        end

        def index_helper
          if options[:model_name]
            controller_file_path.gsub('/', '_')
          else
            super
          end
        end
    end
  end
end
