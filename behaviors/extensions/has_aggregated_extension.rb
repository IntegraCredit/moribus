module Core
  module Behaviors
    module Extensions
      # Minor extension for Rails' +belongs_to+ association that will correct
      # foreign key assignment during association autosave.
      module HasAggregatedExtension
        # Return +true+ if the association has an @updated value (set by
        # default Rails behavior) or if the target record was updated during
        # lookup, indicating that the association owner's foreign key should
        # be updated also.
        def updated?
          @updated || target.try(:updated_as_aggregated?)
        end

        # This helper class is used to effectively extend +has_aggregated+
        # association by adding attribute delegation of attributes and enum
        # readers to the effective reader of the association owner. Behaves
        # much like ActiveRecord::Associations::Builder classes.
        class Helper
          # Among all attribute methods, we're interested only in reader and
          # writers - discard the rest
          EXCLUDE_METHODS_REGEXP = /^_|\?$|^reset|_cast$|_was$|_change!?$|lock_version/

          attr_reader :model, :reflection

          # Save association owner and reflection for subsequent processing.
          def initialize(model, reflection)
            @model, @reflection = model, reflection
          end

          # Extend association: add the delegation module to the reflection,
          # fill it with the delegation methods and include it into the model.
          def extend
            define_delegation_module(reflection)
            add_delegated_methods(reflection)
            include_delegation_module(reflection)
          end

          # Define the delegation module for a reflection, available through
          # #delegated_attribute_methods* method.
          def define_delegation_module(reflection)
            def reflection.delegated_attribute_methods
              @delegated_attribute_methods ||= Module.new
            end
          end
          private :define_delegation_module

          # Add all the interesting methods of the association's klass:
          # generated attribute readers and writers, as well as enum readers
          # and writers.
          def add_delegated_methods(reflection)
            mod = reflection.delegated_attribute_methods
            model.define_attribute_methods unless model.attribute_methods_generated?
            methods_to_delegate = methods_to_delegate_to(reflection) - model.instance_methods
            methods_to_delegate.each do |method|
              mod.delegate method, :to => name
            end
          end
          private :add_delegated_methods

          # Return a list of methods we want to delegate to the association:
          # will generate attribute methods for a klass if they have not yet
          # been generated by Rails, and will select reader and writer methods
          # from the generated model. Also, adds enum readers and writers to
          # a result.
          def methods_to_delegate_to(reflection)
            klass = reflection.klass
            enum_methods = klass.reflect_on_all_enumerated.map do |reflection|
              name = reflection.name
              [name, "#{name}="]
            end
            klass.define_attribute_methods unless klass.attribute_methods_generated?
            attribute_methods = klass.generated_attribute_methods.instance_methods.select{ |m| m !~ EXCLUDE_METHODS_REGEXP }
            attribute_methods + enum_methods.flatten
          end
          private :methods_to_delegate_to

          # Include the reflection's attributes delegation module into a model.
          def include_delegation_module(reflection)
            model.send(:include, reflection.delegated_attribute_methods)
          end
          private :include_delegation_module

          # Return the effective name of the association we're delegating to.
          def name
            @reflection_name ||= "effective_#{reflection.name}"
          end
          private :name
        end
      end
    end
  end
end
