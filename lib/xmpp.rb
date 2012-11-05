require "xmpp4r"
require "xmpp4r/client" 
require "xmpp4r/iq"
require "xmpp4r/command/iq/command"
require "xmpp4r/dataforms/x/data"
require "xmpp4r/errors"

class RollcallXMPP::XMPPClient
  def initialize(domain, admin_jid, admin_password)
    @domain = domain
    @admin_jid = admin_jid
    @admin_password = admin_password

    @actions = [] # actions that have been successfully completed
  end

  def add_user(username, password)
    # TODO: maybe delete any existing account first before creating it to avoid mismatches/conflicts?

    jid = Jabber::JID::new(username, @domain)

    Rails.logger.debug "rollcall-xmpp: Creating XMPP account for #{jid}..."

    result = nil
    begin
      result = command("add-user", {
        'accountjid' => jid.to_s,
        'password' => password,
        'password-verify' => password
      })
    rescue Jabber::ServerError => e
      xmpp_error = "Failed to create XMPP account for #{jid} (#{e} - #{e.error})" 
      Rails.logger.warn "rollcall-xmpp: #{xmpp_error}"
      raise Error, xmpp_error
    rescue => e
      xmpp_error = "Failed to create XMPP account for #{jid} (#{e})" 
      Rails.logger.warn "rollcall-xmpp: #{xmpp_error}"
      raise Error, xmpp_error
    end

    # result.write(xml = "", 2)
    # puts "<< #{xml}"

    process_command_result(result, "account created for #{jid}", "failed to create account for #{jid}")
  end

  def change_user_password(username, new_password)
    jid = Jabber::JID::new(username, @domain)

    Rails.logger.debug "rollcall-xmpp: Changing XMPP password for #{jid} to #{new_password.inspect}..."

    result = nil
    begin
      result = command("change-user-password", {
        'accountjid' => jid.to_s,
        'password' => new_password
      })
    rescue Jabber::ServerError => e
      xmpp_error = "Failed to change XMPP password for #{jid} (#{e} - #{e.error})" 
      Rails.logger.warn "rollcall-xmpp: #{xmpp_error}"
      raise Error, xmpp_error
    rescue => e
      xmpp_error = "Failed to change XMPP password for #{jid} (#{e})" 
      Rails.logger.warn "rollcall-xmpp: #{xmpp_error}"
      raise Error, xmpp_error
    end

    process_command_result(result, "password changed for #{jid}", "failed to change password for #{jid}")
  end
  
  def delete_user(username)
    jid = Jabber::JID::new(username, @domain)

    Rails.logger.debug "rollcall-xmpp: Deleting XMPP account for #{jid}..."

    result = nil
    begin
      result = command("delete-user", {
        'accountjids' => jid.to_s
      })
    rescue Jabber::ServerError => e
      xmpp_error = "Failed to delete XMPP account for #{jid} (#{e} - #{e.error})" 
      Rails.logger.warn "rollcall-xmpp: #{xmpp_error}"
      raise Error, xmpp_error
    rescue => e
      xmpp_error = "Failed to delete XMPP account for #{jid} (#{e})" 
      Rails.logger.warn "rollcall-xmpp: #{xmpp_error}"
      raise Error, xmpp_error
    end

    # result.write(xml = "", 2)
    # puts "<< #{xml}"

    process_command_result(result, "account deleted for #{jid}", "failed to delete account for #{jid}")
  end

  def connect!
    # TODO: reuse client/connections instead of creating a new one for each operation
    client = Jabber::Client.new(@admin_jid)
    client.connect
    
    begin
      client.auth(@admin_password)
    rescue Jabber::ClientAuthenticationFailure
      xmpp_error = "Couldn't authenticate with XMPP server as (#{@admin_jid})! Make sure that the admin account matching your RollcallXMPP configuration has been configured on the XMPP server."
      client.close

      Rails.logger.error "rollcall-xmpp: #{xmpp_error}"
      raise Error, xmpp_error
    end

    @client = client
  end

  def disconnect!
    client.close
  end

  def completed_actions
    @actions
  end

  def client
    unless @client
      connect!
    end
    # TODO: check that client is actually connected
    @client
  end


  class Error < StandardError
  end

  private
  def start_command_session(command)
    iq = Jabber::Iq.new(:set, @domain)
    cmd = Jabber::Command::IqCommand.new('http://jabber.org/protocol/admin#'+command, :execute)
    iq << cmd
    # iq.write(xml = "", 2)
    # puts ">> #{xml}"

    sessionid = client.send_with_id(iq) do |riq|
      # riq.write(xml = "", 2)
      # puts "<< #{xml}"
      riq.command.sessionid
    end

    return sessionid
  end

  def command(command, data)
    sessionid = start_command_session(command)

    iq = Jabber::Iq.new(:set, @domain)
    cmd = Jabber::Command::IqCommand.new('http://jabber.org/protocol/admin#'+command)
    cmd.sessionid = sessionid

    form = Jabber::Dataforms::XData.new(:submit)
    
    f = Jabber::Dataforms::XDataField.new('FORM_TYPE', :hidden)
    f.value = "http://jabber.org/protocol/admin"
    form << f

    data.each do |k, v|
      f = Jabber::Dataforms::XDataField.new(k)
      f.value = v
      form << f
    end
    
    cmd << form
    iq << cmd
  
    # iq.write(xml = "", 2)
    # puts ">> #{xml}"

    return client.send_with_id(iq)
  end

  def process_command_result(result, success_text, failure_text)
    result_note = result.command.elements['note']

    # Prosody resturns 'completed' even if the command failed (because of a dupe account, or invalid account, etc.)
    # So for prosody, we check the result note type. Under ejabberd, these conditions will soemtimes result in a ServerError,
    # but sometimes there will be no indication that it failed (as for example when we try to add a duplicate account).
    if result.command.status == :completed && (!result_note || result_note.attributes['type'] == 'info')
      if result_note
        msg = "XMPP: #{result_note.text}"
      else
        msg = "XMPP: #{success_text}."
      end
      Rails.logger.info "rollcall-xmpp: #{msg} (#{result_note})"
      @actions << msg
    else
      reason = result_note ? "#{result_note.text} (#{result_note.attributes['type']})" : result.command.to_s
      failure = "XMPP: #{failure_text} because: #{reason}!" 
      Rails.logger.warn "rollcall-xmpp: #{failure}"
      raise Error, failure
    end
  end
end