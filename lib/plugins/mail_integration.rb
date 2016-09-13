# Monkey Patch for SMTP Issue
require 'net/smtp'

class << Net::SMTP
  remove_method :default_ssl_context # if defined?(Net::SMTP.default_ssl_context)
end

module Net
  class SMTP
    def SMTP.default_ssl_context
      OpenSSL::SSL::SSLContext.new('TLSv1_2_client')
    end
  end
end

module Plugin
  class MailIntegration < WorkflowPlugin
    require 'mail'
    property :subject, required: true
    property :message, required: true
    property :to,      required: true

    version APP_VERSION

    register_as :mail

    # Send some email
    def send_email
      # Create a new, basic mail object
      mail = Mail.new do
        # Standard delivery method for SMTP
        delivery_method :smtp, address: CONFIG[:mail][:relay], port: CONFIG[:mail][:port]
      end

      mail.to       = @to
      mail.from     = CONFIG[:mail][:from]
      mail.subject  = @subject
      mail.body     = @message

      mail.header['X-App-Name'] = "Antaeus (#{APP_VERSION})"

      # Actual sending is done in its own thread (asynchronously)
      Thread.new { mail.deliver }
    end

    def run
      send_email
    end
  end
end
