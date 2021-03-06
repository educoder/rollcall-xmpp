require 'uri'
require 'account'

Account.class_eval do
  unless Rails.env == 'test'
    require 'xmpp'
    Rails.logger.debug "rollcall-xmpp: Loaded XMPP connector for domain #{RollcallXMPP::DOMAIN}."
  
    before_validation do |account|
      unless account.instance_variable_get(:@xmpp)
        xmpp = RollcallXMPP::XMPPClient.new(RollcallXMPP::DOMAIN, RollcallXMPP::ADMIN_JID, RollcallXMPP::ADMIN_PASSWORD)
        xmpp.connect!
        account.instance_variable_set(:@xmpp, xmpp)
      end
    end

    before_validation :on => :create, :if => proc{ !login.blank? && !password.blank? } do |account|
      # validation seems to be triggered multiple times, but we want to do this only once
      if account.instance_variable_get(:@xmpp).completed_actions.empty?
        begin
          account.instance_variable_get(:@xmpp).add_user(account.login, account.encrypted_password)
        rescue RollcallXMPP::XMPPClient::Error => e
          if e.to_s.include? "Account already exists" # FIXME: hacky!
            Rails.logger.debug "rollcall-xmpp: XMPP says the account #{account.login.inspect} already exists... Trying to change its password to #{account.encrypted_password.inspect}"
            account.instance_variable_get(:@xmpp).change_user_password(account.login, account.encrypted_password)
          else
            account.instance_variable_set(:@xmpp_error, e)
          end
        end
      end
    end

    before_validation :on => :update, :if => proc{ !login.blank? && !password.blank? && password_changed? } do |account|
      # validation seems to be triggered multiple times, but we want to do this only once
      if account.instance_variable_get(:@xmpp).completed_actions.empty?
        begin
          account.instance_variable_get(:@xmpp).change_user_password(account.login, account.encrypted_password)
        rescue RollcallXMPP::XMPPClient::Error => e
          account.instance_variable_set(:@xmpp_error, e)
        end
      end
    end

    # FIXME: not sure how to validate this... :(
    before_destroy do |account|
      # before_validation is skipped with this callback... not sure how else to do this
      xmpp = RollcallXMPP::XMPPClient.new(RollcallXMPP::DOMAIN, RollcallXMPP::ADMIN_JID, RollcallXMPP::ADMIN_PASSWORD)
      xmpp.connect!
      begin
        xmpp.delete_user(account.login)
      rescue RollcallXMPP::XMPPClient::Error => e
        account.errors[:base] << e
        return false
      ensure
        xmpp.disconnect!
      end
    end

    after_save do |account|
      xmpp = account.instance_variable_get(:@xmpp)
      xmpp.disconnect! if xmpp
    end

    validate do
      if (self.login + "@" + RollcallXMPP::DOMAIN) == RollcallXMPP::ADMIN_JID
        self.errors.add(:login, "cannot be the same as the XMPP Admin JID")
      end
      self.errors[:base] << @xmpp_error.to_s if @xmpp_error
    end
  end
end