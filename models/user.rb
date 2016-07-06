# User model for working with LDAP users
class User < LDAP::Model
  ldap_attr CONFIG[:ldap][:userattr].to_sym
  ldap_attr CONFIG[:ldap][:mailattr].to_sym
  ldap_attr CONFIG[:ldap][:displayname].to_sym

  def api_token
    ApiToken.first_or_create(dn: dn)
  end

  # Dynamically construct a DN from the login attribute
  def self.from_login(login)
    from_dn("#{CONFIG[:ldap][:userattr]}=#{login},#{CONFIG[:ldap][:userbase]}")
  end

  # Authenticate a user from their API token
  def self.from_token(token)
    begin
      login, real_token = decrypt(token).split(';;;')
    rescue => e
      fail 'Invalid Token'
    end

    user = from_login(login)
    if user.api_token.value == real_token
      return user
    else
      fail 'No Matching Token'
    end
  end

  def groups
    Group.with_member(self)
  end

  def display_name
    send(CONFIG[:ldap][:displayname].downcase.to_sym)
  end

  def admin?
    query = "#{CONFIG[:ldap][:groupattr]}=#{CONFIG[:ldap][:admin_group]},"
    query << CONFIG[:ldap][:groupbase]
    Group.from_dn(query).members.include?(self)
  end

  # Appointments where the current user is the contact
  def appointments
    Appointment.all(contact: to_s)
  end

  # Appointments created_by the current user
  def created_appointments
    Appointment.all(created_by: to_s)
  end
end
