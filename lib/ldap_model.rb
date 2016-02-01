module LDAP
  class Model
    include Comparable

    def initialize(entity)
      @entity = entity
      self.class.class_eval do
        generate_single_value_readers
        generate_multi_value_readers
      end
    end

    # A DSL method for defining LDAP Attributes we care about
    def self.ldap_attr(name, options = {})
      # Make sure these are initialized
      @single_value_attributes ||= []
      @multi_value_attributes  ||= []

      attribute = name.to_sym
      if options.key?(:pre) && options[:pre].is_a?(Proc)
        attribute = [name.to_sym, options[:pre]]
      end

      # Insert our attribute in the right place
      if options.key?(:type) && options[:type].to_sym == :multi
        unless @multi_value_attributes.collect {|mva| [*mva].first }.include? name.to_sym
          @multi_value_attributes << attribute
        end
      elsif options.key?(:type) && options[:type].to_sym != :single
        fail "Invalid LDAP Attribute Type"
      else
        unless @single_value_attributes.collect {|sva| [*sva].first }.include? name.to_sym
          @single_value_attributes << attribute
        end
      end
    end

    # This should be overloaded
    def self.single_value_attributes
      @single_value_attributes ||= []
    end

    # This should be overloaded
    def self.multi_value_attributes
      @multi_value_attributes  ||= []
    end

    def self.generate_single_value_readers
      single_value_attributes.each do |attribute|
        val, block = Array(attribute)
        define_method(val) do
          if @entity.attribute_names.include?(val)
            if block.is_a?(Proc)
              return block[@entity.send(val).to_s]
            else
              return @entity.send(val).first.to_s
            end
          else
            return nil
          end
        end
      end
    end

    def self.generate_multi_value_readers
      multi_value_attributes.each do |attribute|
        val, block = Array(attribute)
        define_method(val) do
          if @entity.attribute_names.include?(val)
            if block.is_a?(Proc)
              return @entity.send(val).collect(&block)
            else
              return @entity.send(val)
            end
          else
            return []
          end
        end
      end
    end

    # Return all instances available for this class
    def self.all
      attrs = [*single_value_attributes, *multi_value_attributes, :dn].uniq
      LDAP.search(
        "(#{CONFIG[:ldap]["#{self.to_s.downcase}attr".to_sym]}=*)",
        CONFIG[:ldap]["#{self.to_s.downcase}base".to_sym],
        attrs
      ).collect do |entry|
        new(entry)
      end
    end

    def dn
      @entity.dn
    end

    def to_s
      @entity.send(CONFIG[:ldap]["#{self.class.to_s.downcase}attr".to_sym].to_sym).first.to_s
    end

    def to_json(options)
      json_data = {}
      [:dn, *self.class.single_value_attributes].uniq.each do |attribute|
        json_data[attribute.to_sym] = [*@entity.send(attribute.to_sym)].first
      end
      self.class.multi_value_attributes.each do |attribute|
        json_data[attribute.to_sym] = @entity.send(attribute.to_sym)
      end
      json_data.to_json(options)
    end

    def self.from_dn(the_dn)
      filter = the_dn.split(',')[0]
      entries = LDAP.search(filter)
      if entries.nil? || entries.empty?
        fail "Unknown LDAP #{self}"
      elsif entries.size > 1
        fail "Ambiguous LDAP #{self}"
      else
        return new(entries.first)
      end
    end

    def <=>(other)
      if self.dn < other.dn
        -1
      elsif self.dn > other.dn
        1
      elsif self.dn == other.dn
        0
      else
        fail "Invalid Comparison"
      end
    end
  end
end