# A very simple implementation of a workflow hook / event trigger
module Workflowable
  def trigger(event, object = nil)
    puts "[Workflow Event @ #{Time.now.strftime("%d/%b/%Y:%H:%M:%S %z")}]: " +
      "Triggering `#{event}`" if debugging?

    # Move plugin operation to background threads 
    Concurrent::Promise.new { WorkflowHook.all(name: event.to_s) }.then do |hooks|
      hooks.each do |hook|
        hook.plugins.each do |hook_plugin|
          puts "[Workflow Event @ #{Time.now.strftime("%d/%b/%Y:%H:%M:%S %z")}]: " +
            "Triggering hook `#{hook_plugin}` for `#{event}`" if debugging?
          # TODO: get all configurations
          hook_config = {}
          # Default config
          hook_config.merge!(hook.configurations[hook_plugin]) if hook.configurations.key?(hook_plugin)

          # Use the object passed in for interpolations in the hook_config
          interpolated_hook_config = if object
                                       Hash[ hook_config.map { |k, v| [k, strip_erb(v, binding)] } ]
                                     else
                                       hook_config
                                     end

          # Execute the plugin with the config
          plugin = Plugins.instance[hook_plugin.to_sym][:provider].new
          plugin.execute(interpolated_hook_config)
        end
      end
    end.then do |result|
      puts "[Workflow Event @ #{Time.now.strftime("%d/%b/%Y:%H:%M:%S %z")}]: " +
        "Event `#{event}` complete" if debugging?
    end.execute
  end

  private

  def strip_erb(content, binding_point)
    ERB.new(
      content.gsub(/^(\t|\s)+<%/, '<%'), 0, "<>"
    ).result(binding_point)
  end
end
