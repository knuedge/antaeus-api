class User < LDAP::Model
  ldap_attr CONFIG[:ldap][:userattr].to_sym
  ldap_attr CONFIG[:ldap][:mailattr].to_sym

  def self.all
    LDAP.search("(#{CONFIG[:ldap][:userattr]}=*)", CONFIG[:ldap][:userbase]).collect do |entry|
      self.new(entry)
    end
  end

  def api_token
    ApiToken.first_or_create(dn: dn)
  end

  # Dynamically construct a DN from the login attribute
  def self.from_login(login)
    from_dn("#{CONFIG[:ldap][:userattr]}=#{login},#{CONFIG[:ldap][:userbase]}")
  end

  # Authenticate a user from their API token
  def self.from_token(login, token)
    user = from_login(login)
    if user.api_token.value == token
      return user
    else
      fail "No Matching Token"
    end
  end

  def groups
    Group.with_member(self)
  end

  def admin?
    query = "#{CONFIG[:ldap][:groupattr]}=#{CONFIG[:ldap][:admin_group]},#{CONFIG[:ldap][:groupbase]}"
    Group.from_dn(query).members.include?(self)
  end
end