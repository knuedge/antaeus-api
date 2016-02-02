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
    @@ldap_connection.bind
  end
  
  def self.connection
    begin
      @@ldap_connection
    rescue => e
      fail "LDAP Not Connected!"
    end
  end

  def self.search(filter, base = CONFIG[:ldap][:basedn], attrs = [])
    connection.search(base: base, filter: filter, attributes: attrs.map {|a| a.to_s})
  end

  # Test a user's auth
  def self.test_auth(dn, pass)
    temp = Net::LDAP.new(
      host: CONFIG[:ldap][:host],
      port: CONFIG[:ldap][:port],
      auth: {
        method: :simple,
        username: dn,
        password: pass
      }
    )
    temp.bind
  end
end
