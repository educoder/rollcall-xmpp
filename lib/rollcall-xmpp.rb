module RollcallXMPP
  class Railtie < Rails::Railtie
    config.xmpp = ActiveSupport::OrderedOptions.new

    initializer 'xmpp.initialize' do |app|      
      if config.xmpp.domain
        RollcallXMPP::DOMAIN = config.xmpp.domain
      else
        raise "No domain configured for RollcallXMPP! Please set `config.xmpp.domain` in config/application.rb or config/environments/*.rb."
      end

      if config.xmpp.admin_jid
        RollcallXMPP::ADMIN_JID = config.xmpp.admin_jid
      else
        RollcallXMPP::ADMIN_JID = 'rollcall@' + RollcallXMP::DOMAIN 
      end

      if config.xmpp.admin_password
        RollcallXMPP::ADMIN_PASSWORD = config.xmpp.admin_password
      else
        raise "No admin password configured for RollcallXMPP! Please set `config.xmpp.admin_password` in config/application.rb or config/environments/*.rb."
      end
      
      require 'account_callbacks'
    end
    
  end
end