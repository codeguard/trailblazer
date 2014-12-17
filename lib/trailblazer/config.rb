require 'trollop'
require 'yaml'
require 'pp'

module Trailblazer

  class Config

    DEFAULTS = {
      ip_url: 'https://ip-ranges.amazonaws.com/ip-ranges.json',
      ip_target: 'gateway',
      ip_ranges: %w(us-east-1 GLOBAL),
      ip_services: %w(AMAZON),
      loglevel: 'info',
      verbose: false
    }

    # Process all command-line arguments and merge them with the given configuration
    # file's YAML if there is one.
    def initialize
      cmdline = cmdline_options
      if File.exist?(filename = cmdline[:config])
        cfgfile = cfgfile_options(filename)
        @config = merge_options cfgfile, cmdline
      else
        @config = merge_options Hash.new, cmdline
      end
    end

    def method_missing(name, *args, &blk)
      if name =~ /(.+)\?$/
        !@config[$1.to_sym].nil?
      elsif @config.key?(name.to_sym)
        @config[name.to_sym]
      else
        super
      end
    end


   private

   def cmdline_options
     Trollop.options do
       version "trailblazer #{Trailblazer::VERSION}"
       opt :config, 'Configuration file', default: File.expand_path('~/.trailblazer.yml')
       opt :access_key, 'AWS access key', type: :string
       opt :secret_key, 'AWS secret key', type: :string
       opt :route_table, 'Route table (canonical ID)', type: :string, short: :t
       opt :route, "Custom routes to add to route table ('CIDR=target')", multi: true, type: :string, short: :r
       opt :ip_target, 'Target for routes from ip-ranges list', type: :string, short: :g
       opt :ip_url, 'Location of ip-ranges.json list', type: :string, short: :u
       opt :ip_region, 'Region filter for ip-ranges list (default: us-east-1, GLOBAL)', multi: true, type: :string, short: :e
       opt :ip_service, 'Service filter for ip-ranges list (default: AMAZON)', multi: true, type: :string, short: :a
       opt :loglevel, 'Event detail: debug, info, warn, error', type: :string, short: :l
       opt :logfile, 'Local file for event logging', type: :string, short: :f
       opt :notification, 'SNS topic for results (canonical ID)', type: :string, short: :n
       opt :verbose, 'Send notification on runs with no changes', short: :v
     end
   end

   def cfgfile_options(filename)
     opts, cfg = {}, YAML.load_file(filename)

     opts[:route_table] = cfg['route_table']
     if aws = cfg['aws']
       opts[:access_key] = aws['access_key_id'] if aws['access_key_id']
       opts[:secret_key] = aws['secret_access_key'] if aws['secret_access_key']
     end

     if ip = cfg['ip_ranges']
       opts[:ip_target] = ip['target'] if ip['target']
       opts[:ip_url] = ip['url'] if ip['url']
       opts[:ip_services] = ip['services'] if ip['services']
       opts[:ip_regions] = ip['regions'] if ip['regions']
     end

     if logging = cfg['logging']
       opts[:logfile] = File.expand_path(logging['filename']) if logging['filename']
       opts[:loglevel] = logging['level'] if logging['level']
     end

     if notify = cfg['notification']
       opts[:notification] = notify['topic'] if notify['topic']
       opts[:verbose] = notify['verbose'] if notify['verbose']
     end

     opts[:routes] = cfg.fetch('routes', {})

     opts
   end

   def merge_options(cfg, cmd)
     cfg[:ip_services] ||= ['AMAZON']
     if cmd[:ip_service]
       cfg[:ip_services] += cmd.delete(:ip_service)
     end

     cfg[:ip_regions] ||= ['GLOBAL', 'us-east-1']
     if cmd[:ip_region]
       cfg[:ip_regions] += cmd.delete(:ip_region)
     end

     cfg[:routes] ||= {}
     unless cmd[:route].empty?
       cmd_routes = cmd.delete(:route).collect { |r| r.split('=') }
       cfg[:routes].merge! Hash[cmd_routes]
     end

     cmd.each do |key, val|
       cfg[key] = val unless val.nil? || val == [] || val == false
     end

     DEFAULTS.merge cfg
   end
  end
end
