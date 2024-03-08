#!/usr/bin/env ruby

# frozen_string_literal: true

require File.expand_path('../../config/environment', __FILE__)
require 'erb'

class Block
  extend GLI::App

  program_desc 'Blockchain HUB'

  flag :config, desc: 'Path to notif config file'

  command :stop do |c|
    c.action do
    end
  end

  command :run do |c|
    c.desc 'Run processing block events'
    c.action do |global_options, _options, _args|
        BlockService.call(ENV.fetch('BLOCK_EXCHANGE_NAME'))
    end
  end
end

exit Block.run(ARGV)