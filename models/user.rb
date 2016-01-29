class User < LDAP::Model
  ldap_attr CONFIG[:ldap][:userattr].to_sym
  ldap_attr CONFIG[:ldap][:mailattr].to_sym

  def self.all
    LDAP.search("(#{CONFIG[:ldap][:userattr]}=*)", CONFIG[:ldap][:userbase]).collect do |entry|
      self.new(entry)
    end
  end
end