# frozen_string_literal: true

Dir[File.expand_path('custom_matchers/**/*.rb', __dir__)].sort.each { |f| require f }