require 'trollop'
require 'yaml'

module Trailblazer

  class Config

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
       opt :route, "Custom routes to add to route table ('CIDR=target')", multi: true, type: :strings
       opt :ip_target, 'Target for routes from ip-ranges list', default: 'gateway', short: :g
       opt :ip_url, 'Location of ip-ranges.json list', default: 'https://ip-ranges.amazonaws.com/ip-ranges.json', short: :u
       opt :ip_region, 'Region filter for ip-ranges list (default: us-east-1, GLOBAL)', multi: true, type: :strings, short: :e
       opt :ip_service, 'Service filter for ip-ranges list (default: AMAZON)', multi: true, type: :strings, short: :a
       opt :notification, 'SNS topic for results (canonical ID)', type: :string
       opt :verbose, 'Send notification on runs with no changes'
     end
   end

   def cfgfile_options(filename)
     opts, cfg = {}, YAML.load_file(filename)
     opts[:route_table] = cfg['route_table']
     if aws = cfg['aws']
       opts[:access_key] = aws['access_key_id']
       opts[:secret_key] = aws['secret_access_key']
     end

     if ip = cfg['ip_ranges']
       opts[:ip_target] = ip['target']
       opts[:ip_url] = ip['url']
       opts[:ip_services] = ip['services']
       opts[:ip_regions] = ip['regions']
     end

     if notify = cfg['notification']
       opts[:notification] = notify['topic']
       opts[:verbose] = notify['verbose']
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

     cfg.merge cmd
   end

  end
end
