require 'rspec-puppet'

fixture_path = File.expand_path(File.join(__FILE__, '..', 'fixtures'))

RSpec.configure do |c|
  c.module_path = '/etc/puppet/modules'
  c.manifest_dir = File.join(fixture_path, 'manifests')

  # Coverage generation
  c.after(:suite) do
    RSpec::Puppet::Coverage.report!
  end

end