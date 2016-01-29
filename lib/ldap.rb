module LDAP
  def self.connect!
    @@ldap_connection ||= Net::LDAP.new(
      host: CONFIG[:ldap][:host],
      port: CONFIG[:ldap][:port],
      base: CONFIG[:ldap][:basedn],
      auth: {
        method: :simple,
        username: CONFIG[:ldap][:username],
        password: CONFIG[:ldap][:password]
      }
    )
    return @@ldap_connection.bind
  end
  
  def self.connection
    begin
      @@ldap_connection
    rescue => e
      fail "LDAP Not Connected!"
    end
  end

  def self.search(filter, base = CONFIG[:ldap][:basedn])
    connection.search(base: base, filter: filter)
  end
end