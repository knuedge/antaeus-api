class Group < LDAP::Model
  ldap_attr CONFIG[:ldap][:groupattr].to_sym
  ldap_attr CONFIG[:ldap][:memberattr].to_sym, type: :multi

  def self.all
    LDAP.search("(#{CONFIG[:ldap][:groupattr]}=*)", CONFIG[:ldap][:groupbase]).collect do |entry|
      self.new(entry)
    end
  end

  def members
    self.send(CONFIG[:ldap][:memberattr].to_sym).map do |m|
      User.new(m)
    end
  end
end