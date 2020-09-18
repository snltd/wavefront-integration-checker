# frozen_string_literal: true

load 'vendor/bundle/bundler/setup.rb'
require 'pathname'
require 'wavefront-sdk/cloudintegration'
require 'wavefront-sdk/write'
require 'logger'

def query_integrations(event:, context:)
  abort 'unset Wavefront endpoint' if ENV['WF_ENDPOINT'].nil?
  abort 'unset Wavefront token ' if ENV['WF_TOKEN'].nil?

  creds = { endpoint: ENV['WF_ENDPOINT'], token: ENV['WF_TOKEN'] }
  metric_path = ENV['WF_PATH'] || 'sre.wavefront.integrations'
  log = Logger.new(STDERR, level: :warn)

  timestamp = Time.now.to_i
  integrations = Wavefront::CloudIntegration.new(creds, logger: log)
                                              .list(limit: :all)

  abort 'Failed to fetch integration list. Check token.' unless integrations.ok?

  points = integrations.response.items.map do |integration|
    { path: metric_path,
      ts: timestamp,
      source: 'wavefrontIntegrationMonitor',
      value: integration[:lastMetricCount],
      tags: { name: integration[:name], type: integration[:service] } }
  end

  Wavefront::Write.new(creds, writer: :api, logger: log).write(points).ok?
end
