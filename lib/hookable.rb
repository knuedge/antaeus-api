module Hookable
  # Add a hook to be triggered by an event
  def register_hook(*args)
    AvailableHooks.instance.concat args.flatten
  end
end
