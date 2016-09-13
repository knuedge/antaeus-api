class WorkflowPlugin
  # Replace attr_accessor so we can track attributes
  def self.property(name, options = {})
    @required_properties ||= []
    @optional_properties ||= []
 
    attr_accessor name.to_sym

    if options[:required]
      @required_properties << name.to_sym
    else
      @optional_properties << name.to_sym
    end
  end

  def self.required_properties
    @required_properties
  end

  def self.optional_properties
    @optional_properties
  end

  def self.properties
    required_properties + optional_properties
  end

  def self.register_as(name)
    register_plugin(
      name,
      self,
      version: version,
      properties: { required: required_properties, optional: optional_properties }
    )
  end

  def self.version(v = nil)
    @version ||= '0.0.1'
    if v.nil?
      @version
    else
      @version = v
    end
  end

  def required_properties
    self.class.required_properties
  end

  def optional_properties
    self.class.optional_properties
  end

  def properties
    self.class.properties
  end

  def version
    self.class.version
  end

  # Don't touch this... used for calling workflow steps internally
  def execute(options = {})
    # load all the options for this plugin
    options.each { |name,value| send("#{name}=".to_sym, value) }

    # validate we have the properties we need
    validate_properties

    # run the workflow plugin
    run
  end

  # This method *must* be overridden to make this plugin do something
  def run
    false
  end

  private

  def validate_properties
    missing_properties = []
    required_properties.each do |prop|
      missing_properties << prop if send(prop.to_sym).nil?
    end
    raise Exceptions::MissingProperty unless missing_properties.empty?
  end
end
