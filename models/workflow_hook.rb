class WorkflowHook
  include DataMapper::Resource
  include Serializable

  property :id,         Serial
  property :name,       String,   length: 4..255, required: true, index: true
  property :plugins,    Json,     lazy: false
  property :configurations, Json, lazy: false
  property :created_at, DateTime
  property :updated_at, DateTime
end
