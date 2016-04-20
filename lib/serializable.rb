# Poor-man's implementation of ActiveRecord::Serializer
module Serializable
  def serialize(options = {})
    if is_a?(DataMapper::Collection) || is_a?(LDAP::Collection)
      root = model.name.en.plural.to_underscore
    elsif is_a?(Array)
      fail "Exceptions::EmptyArrayRoot" if empty?
      root = first.class.name.en.plural.to_underscore
    else
      root = self.class.name.to_underscore
    end
    if options.has_key?(:root)
      root = options[:root]
    end

    options[:format] ||= :json
    { root => prepare_for_serialization(options) }.send("to_#{options[:format]}".to_sym)
  end

  def prepare_for_serialization(options = {})
    if is_a?(LDAP::Collection) || is_a?(DataMapper::Collection) || is_a?(Array)
      return PooledIterator.collect(self, 8) do |serializable_model|
        if serializable_model.respond_to?(:prepare_for_serialization)
          serializable_model.prepare_for_serialization(options)
        elsif serializable_model.respond_to?(:to_hash)
          serializable_model.to_hash
        else
          serializable_model.to_s
        end
      end
    elsif options[:only]
      results = {}
      [*options[:only]].each do |m|
        results[m.to_sym] = send(m.to_sym)
      end
    elsif respond_to?(:attributes)
      additional_data = {}
      [*options[:methods], *options[:include]].uniq.each do |m|
        additional_data[m.to_sym] = send(m.to_sym)
      end
      
      results = attributes.merge(additional_data)
      [*options[:exclude]].each do |exclude|
        results.delete(exclude.to_sym)
      end
    else
      additional_data = {}
      [*options[:methods], *options[:include]].uniq.each do |m|
        additional_data[m.to_sym] = send(m.to_sym)
      end
      
      results = to_hash.merge(additional_data)
      [*options[:exclude]].each do |exclude|
        results.delete(exclude.to_sym)
      end
    end

    if options[:relationships]
      options[:relationships].each do |relationship_name, opts|
        if respond_to?(relationship_name)
          results[relationship_name] = send(relationship_name.to_sym).
            prepare_for_serialization(opts)
        end
      end
    end
    results
  end
end
