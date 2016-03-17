module LDAP
  class Model
    include Comparable
    include ::Serializable

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
      @multi_value_attributes ||= []

      attribute = name.to_sym
      if options.key?(:pre) && options[:pre].is_a?(Proc)
        attribute = [name.to_sym, options[:pre]]
      end

      # Insert our attribute in the right place
      if options.key?(:type) && options[:type].to_sym == :multi
        unless @multi_value_attributes.collect { |mva| [*mva].first }.include? name.to_sym
          @multi_value_attributes << attribute
        end
      elsif options.key?(:type) && options[:type].to_sym != :single
        fail 'Invalid LDAP Attribute Type'
      else
        unless @single_value_attributes.collect { |sva| [*sva].first }.include? name.to_sym
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
      @multi_value_attributes ||= []
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
      attrs  = [*single_value_attributes, *multi_value_attributes, :dn].uniq
      filter = "(#{CONFIG[:ldap]["#{to_s.downcase}attr".to_sym]}=*)"
      base   = CONFIG[:ldap]["#{to_s.downcase}base".to_sym]
      cache_key = "all_#{filter}_#{base}"
      result_data = cache_fetch(cache_key, expires: 900) { LDAP.search(filter, base, attrs) }
      cache_fetch("#{to_s.downcase}_all", expires: 300) do
        PooledIterator.collect(result_data, 4, Collection) do |entry|
          cache_fetch(entry.dn, expires: 300) { new(entry) }
        end
      end
    end

    def self.first(n = nil)
      if n
        all.first(n)
      else
        all.first
      end
    end

    def self.last(n = nil)
      if n
        all.last(n)
      else
        all.last
      end
    end

    # Do an LDAP Search
    # This will eventually need to be made safer (preventing injection in the query)
    def self.search(query)
      attrs  = [*single_value_attributes, *multi_value_attributes, :dn].uniq

      result_data = []
      if CACHE_STATUS == :enabled
        result_data = PooledIterator.collect(all, 8, Collection) do |entry|
          output = nil
          single_value_attributes.each do |ldap_at|
            if entry.send(ldap_at.to_sym).to_s.downcase.match %r(#{query.downcase})
              output = entry.raw
              break
            end
          end
          unless output
            multi_value_attributes.each do |ldap_at|
              if entry.send(ldap_at.to_sym).any? { |v| v.to_s.downcase.match %r(#{query.downcase}) }
                output = entry.raw
                break
              end
            end
          end
          output
        end.compact
      else
        # Build a complex filter for a query on all attributes
        objcl = CONFIG[:ldap]["#{to_s.downcase}objcl".to_sym]
        filter = "(&(objectClass=#{objcl})"
        filter << '(|'
        (attrs - [:dn]).each do |ldap_at|
          filter << "(#{ldap_at}=*#{query}*)"
        end
        filter << '))'

        base   = CONFIG[:ldap]["#{to_s.downcase}base".to_sym]
        cache_key = "search_#{filter}_#{base}"
        result_data = cache_fetch(cache_key, expires: 300) { LDAP.search(filter, base, attrs) }
      end
      cache_fetch("#{to_s.downcase}_search_#{query}", expires: 300) do
        PooledIterator.collect(result_data.uniq, 4, Collection) do |entry|
          cache_fetch(entry.dn, expires: 300) { new(entry) }
        end
      end
    end

    def raw
      @entity
    end

    def dn
      @entity.dn
    end

    # Make requests for "id" provide the RDN value
    def id
      to_s
    end

    def to_s
      @entity.send(identity_attribute).first.to_s
    end

    def identity_attribute
      self.class.identity_attribute
    end

    # DataMapper-style #attributes Hash
    def attributes
      data = {}
      [:dn, *self.class.single_value_attributes].uniq.each do |attribute|
        data[attribute.to_sym] = [*@entity.send(attribute.to_sym)].first
      end
      self.class.multi_value_attributes.each do |attribute|
        data[attribute.to_sym] = @entity.send(attribute.to_sym)
      end
      data
    end

    def to_json(options = {})
      serialize({format: :json}.merge(options))
    end

    def self.from_dn(the_dn)
      cache_fetch(the_dn, expires: 300) do
        filter = the_dn.split(',')[0]
        entries = LDAP.search(filter)
        if entries.nil? || entries.empty?
          fail "Unknown LDAP #{self}"
        elsif entries.size > 1
          fail "Ambiguous LDAP #{self}"
        else
           new(entries.first)
        end
      end
    end

    def self.identity_attribute
      CONFIG[:ldap]["#{to_s.downcase}attr".to_sym].to_sym
    end

    def <=>(other)
      if dn < other.dn
        -1
      elsif dn > other.dn
        1
      elsif dn == other.dn
        0
      else
        fail 'Invalid Comparison'
      end
    end
  end
end
