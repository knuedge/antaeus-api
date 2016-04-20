module LDAP
  class Collection < Array
    def to_json(options = {})
      serialize({format: :json}.merge(options))
    end

    def model=(class_name)
      if @model
        fail "Exceptions::NoOverridingCollectionModel"
      else
        @model = class_name
      end
    end

    def model
      @model
    end
  end
end
