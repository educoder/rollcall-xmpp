Gem::Specification.new do |s|
  s.name = %q{rollcall-xmpp}
  s.version = "0.0.1"
  s.authors = ["Matt Zukowski"]
  s.date = %q{2012-05-17}
  s.summary = %q{Rollcall plugin for automatically creating XMPP accounts via in-band registration}
  s.email = %q{matt dot zukowski at utoronto dot ca}
  s.files = `git ls-files`.split("\n")
  s.homepage = %q{http://github.com/educoder/rollcall-xmpp}
  s.rdoc_options = ["--main", "README"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{rollcall-xmpp}

  s.add_dependency("xmpp4r")
end
