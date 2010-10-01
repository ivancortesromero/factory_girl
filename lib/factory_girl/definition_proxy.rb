module FactoryGirl
  class DefinitionProxy
    instance_methods.each do |method|
      undef_method(method) unless method =~ /(^__|^nil\?$|^send$|^object_id$|^extend$|^instance_eval$)/
    end

    def initialize(factory)
      @factory = factory
    end

    # Adds an attribute that should be assigned on generated instances for this
    # factory.
    #
    # This method should be called with either a value or block, but not both. If
    # called with a block, the attribute will be generated "lazily," whenever an
    # instance is generated. Lazy attribute blocks will not be called if that
    # attribute is overridden for a specific instance.
    #
    # When defining lazy attributes, an instance of Factory::Proxy will
    # be yielded, allowing associations to be built using the correct build
    # strategy.
    #
    # Arguments:
    # * name: +Symbol+ or +String+
    #   The name of this attribute. This will be assigned using :"#{name}=" for
    #   generated instances.
    # * value: +Object+
    #   If no block is given, this value will be used for this attribute.
    def add_attribute(name, value = nil, &block)
      if block_given?
        if value
          raise AttributeDefinitionError, "Both value and block given"
        else
          attribute = Attribute::Dynamic.new(name, block)
        end
      else
        attribute = Attribute::Static.new(name, value)
      end

      @factory.define_attribute(attribute)
    end

    # Calls add_attribute using the missing method name as the name of the
    # attribute, so that:
    #
    #   Factory.define :user do |f|
    #     f.name 'Billy Idol'
    #   end
    #
    # and:
    #
    #   Factory.define :user do |f|
    #     f.add_attribute :name, 'Billy Idol'
    #   end
    #
    # are equivilent.
    def method_missing(name, *args, &block)
      if args.empty? && block.nil?
        if sequence = FactoryGirl.sequences[name]
          add_attribute(name) { sequence.next }
        else
          association(name)
        end
      else
        add_attribute(name, *args, &block)
      end
    end

    # Adds an attribute that will have unique values generated by a sequence with
    # a specified format.
    #
    # The result of:
    #   Factory.define :user do |f|
    #    f.sequence(:email) { |n| "person#{n}@example.com" }
    #   end
    #
    # Is equal to:
    #   Factory.sequence(:email) { |n| "person#{n}@example.com" }
    #
    #   Factory.define :user do |f|
    #    f.email { Factory.next(:email) }
    #   end
    #
    # Except that no globally available sequence will be defined.
    def sequence(name, start_value = 1, &block)
      sequence = Sequence.new(start_value, &block)
      add_attribute(name) { sequence.next }
    end

    # Adds an attribute that builds an association. The associated instance will
    # be built using the same build strategy as the parent instance.
    #
    # Example:
    #   Factory.define :user do |f|
    #     f.name 'Joey'
    #   end
    #
    #   Factory.define :post do |f|
    #     f.association :author, :factory => :user
    #   end
    #
    # Arguments:
    # * name: +Symbol+
    #   The name of this attribute.
    # * options: +Hash+
    #
    # Options:
    # * factory: +Symbol+ or +String+
    #    The name of the factory to use when building the associated instance.
    #    If no name is given, the name of the attribute is assumed to be the
    #    name of the factory. For example, a "user" association will by
    #    default use the "user" factory.
    def association(name, options = {})
      factory_name = options.delete(:factory) || name
      @factory.define_attribute(Attribute::Association.new(name, factory_name, options))
    end

    # Registers an alias for this factory using the given name.
    #
    # Arguments:
    # * name: +Symbol+
    #   The name of the alias.
    #
    # Example:
    #
    #   Factory.define :user do |f|
    #     f.aliased_as :author
    #   end
    #
    #   Factory(:author).class
    #   # => User
    def aliased_as(name)
      FactoryGirl.register_factory(@factory, :as => name)
    end

    def after_build(&block)
      @factory.add_callback(:after_build, &block)
    end

    def after_create(&block)
      @factory.add_callback(:after_create, &block)
    end

    def after_stub(&block)
      @factory.add_callback(:after_stub, &block)
    end
  end
end
