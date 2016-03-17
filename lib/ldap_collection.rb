module LDAP
  class Collection < Array
    def to_json(options = {})
      serialize({format: :json}.merge(options))
    end
  end
end
