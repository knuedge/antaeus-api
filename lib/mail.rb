# Send some email
def send_email(to, subject, message)
  mail = Mail.new do
    if CONFIG[:mail][:gpg][:sign]
      gpg sign: true, password: CONFIG[:mail][:gpg][:passphrase]
    end
    delivery_method :smtp, address: CONFIG[:mail][:relay], port: CONFIG[:mail][:port]
  end

  mail.to       = to
  mail.from     = CONFIG[:mail][:from]
  mail.subject  = subject
  mail.body     = message

  mail.header['X-App-Name'] = "Antaeus (#{APP_VERSION})"

  # Actual sending is done in its own thread (asynchronously)
  Thread.new { mail.deliver }
end