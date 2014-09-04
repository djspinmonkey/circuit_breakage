require 'pry'

lib_dir = File.expand_path('../../lib/', __FILE__)
Dir["#{lib_dir}/**/*.rb"].each { |file| require file }

RSpec.configure do |config|
  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end

  config.order = :random
  Kernel.srand config.seed

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
