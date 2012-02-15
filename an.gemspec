Gem::Specification.new do |s|
  s.name              = "an"
  s.version           = "0.0.1.rc2"
  s.summary           = "A thin Authorize.NET client."
  s.description       = "AN is a simplified client for integration with Authorize.NET."
  s.authors           = ["Cyril David"]
  s.email             = ["me@cyrildavid.com"]
  s.homepage          = "http://github.com/cyx/an"

  s.files = Dir[
    "LICENSE",
    "README",
    "lib/**/*.rb",
    "*.gemspec",
    "test/*.*"
  ]

  s.add_dependency "scrivener"
  s.add_development_dependency "cutest"
end
