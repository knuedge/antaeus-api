class Group < LDAP::Model
  ldap_attr CONFIG[:ldap][:groupattr].to_sym
  ldap_attr CONFIG[:ldap][:memberattr].to_sym, type: :multi

  def self.all
    LDAP.search("(#{CONFIG[:ldap][:groupattr]}=*)", CONFIG[:ldap][:groupbase]).collect do |entry|
      self.new(entry)
    end
  end

  def self.with_member(user)
    query = "(&(#{CONFIG[:ldap][:groupattr]}=*)(#{CONFIG[:ldap][:memberattr]}="
    query << CONFIG[:ldap][:memberref] == 'dn' ? user.dn : user.send(CONFIG[:ldap][:userattr].to_sym)
    query << '))'
    LDAP.search(query, CONFIG[:ldap][:groupbase]).collect do |entry|
      self.new(entry)
    end
  end

  def members
    self.send(CONFIG[:ldap][:memberattr].to_sym).collect do |m|
      if CONFIG[:ldap][:memberref] == 'dn'
        User.from_dn(m)
      else
        User.from_login(m)
      end
    end
  end
end