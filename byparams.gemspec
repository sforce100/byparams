$LOAD_PATH.unshift 'lib'
require "by_params/version"

Gem::Specification.new do |s|
  s.name              = "by_params"
  s.version           = ByParams::VERSION
  s.date              = Time.now.strftime('%Y-%m-%d')
  s.summary           = "Find mongo document or search solr via http params"
  s.homepage          = "http://github.com/brainet/byparams"
  s.email             = "huhao98@gmail.com"
  s.authors           = [ "Hu Hao" ]
  s.has_rdoc          = false

  s.files             = %w( README.md Rakefile)
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("spec/**/*")

#  s.executables       = %w( byparams )
  s.description       = <<desc
  Find mongo document or search solr via http params
desc
end
