rollcall-xmpp
=============

XMPP integration for the Rollcall directory service using ad-hoc admin commands.

Installation
============

1. `cd` into the Rollcall root directory
2. edit the Gemfile and uncomment "rollcall-xmpp"
3. run `bundle --without=development`
4. uncomment and configure the `config.xmpp.*` options at the bottom of `config/environments/production.rb`
5. you will have to give Rollcall the jid and password for a valid admin user (`config.xmpp.admin_jid` and `config.xmpp.admin_password`)
6. restart Rollcall by running `touch tmp/restart.txt`

That's it. Rollcall should now be using adhoc admin commands to manage users on the XMPP server (assuming the server is configured to handle these, and the admin account has the right privileges). 

Tested with both prosody and ejabberd.