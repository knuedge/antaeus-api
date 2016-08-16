# Group model for working with LDAP groups
class Group < LDAP::Model
  ldap_attr CONFIG[:ldap][:groupattr].to_sym
  ldap_attr CONFIG[:ldap][:memberattr].to_sym, type: :multi

  def self.from_attr(name)
    #from_dn("#{CONFIG[:ldap][:groupattr]}=#{name},#{CONFIG[:ldap][:groupbase]}")
    from_filter("#{CONFIG[:ldap][:groupattr]}=#{name}", CONFIG[:ldap][:groupbase])
  end

  def self.with_member(user)
    ldap_conf = CONFIG[:ldap]
    mem_attr  = ldap_conf[:memberref] == 'dn' ? user.dn : user.send(ldap_conf[:userattr].to_sym)

    query = "(&(#{ldap_conf[:groupattr]}=*)(#{ldap_conf[:memberattr]}=#{mem_attr}))"

    LDAP.search(query, base: CONFIG[:ldap][:groupbase], scope: search_scope).collect do |entry|
      new(entry)
    end.compact
  end

  def members
    send(CONFIG[:ldap][:memberattr].to_sym).collect do |m|
      if CONFIG[:ldap][:memberref] == 'dn'
        m.match(/#{CONFIG[:ldap][:userbase]}$/i) ? User.from_dn(m) : nil
      else
        User.from_login(m)
      end
    end.compact
  end
end
