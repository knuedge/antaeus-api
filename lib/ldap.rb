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

  def self.search(filter, options = {})
    base = options.key?(:base) ? options[:base] : CONFIG[:ldap][:basedn]
    attrs = options.key?(:attrs) ? options[:attrs] : []
    scope = options.key?(:scope) ? options[:scope] : 'subtree'

    scope_class = case scope.to_s
      when 'subtree','recursive','whole_subtree'
        Net::LDAP::SearchScope_WholeSubtree
      when 'single','single_level'
        Net::LDAP::SearchScope_SingleLevel
      when 'object','base_object'
        Net::LDAP::SearchScope_BaseObject
      else
        fail "Invalid LDAP Scope!"
      end

    metric_key = 'ldap.query'
    if Metrics.registered?(:counts)
      Metrics.update(:counts, metric_key) {|c| c + 1 }
    end
    puts "[LDAP Query @ #{Time.now.strftime("%d/%b/%Y:%H:%M:%S %z")}]: " +
      "Query for #{filter} from #{base}" if debugging?
    connection.search(base: base, filter: filter, scope: scope_class, attributes: attrs.map {|a| a.to_s}).compact
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
    puts "[LDAP Auth @ #{Time.now.strftime("%d/%b/%Y:%H:%M:%S %z")}]: " +
      "Authentication attempt for #{dn}" if debugging?
    metric_key = 'ldap.authentication'
    if Metrics.registered?(:counts)
      Metrics.update(:counts, metric_key) {|c| c + 1 }
    end
    temp.bind
  end
end
