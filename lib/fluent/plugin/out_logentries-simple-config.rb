require 'socket'
require 'yaml'
require 'openssl'

class Fluent::LogentriesOutput < Fluent::BufferedOutput
  class ConnectionFailure < StandardError; end
  # First, register the plugin. NAME is the name of this plugin
  # and identifies the plugin in the configuration file.
  Fluent::Plugin.register_output('logentries-simple-config', self)

  config_param :use_ssl,        :bool,    :default => true
  config_param :use_json,       :bool,    :default => false
  config_param :port,           :integer, :default => 20000
  config_param :protocol,       :string,  :default => 'tcp'
  config_param :token,          :string
  config_param :extra_tokens,   :string,  :default => nil       # "token1:app1,app2,app3 token2:app11,app12,app13"
  config_param :max_retries,    :integer, :default => 3

  SSL_HOST    = "api.logentries.com"
  NO_SSL_HOST = "data.logentries.com"

  def configure(conf)
    super
  end

  def start
    @app_tokens = if @extra_tokens.present?
      puts "extra_tokens: #{@extra_tokens}"
      token_apps = (@extra_tokens.split(' ')&.select { |v| v&.strip&.presence })&.compact
      puts "token_apps: #{token_apps}"
      if token_apps.present?
        {}.tap do |total_apps|
          token_apps.each do |token_app|
            puts "token_app: #{token_app}"
            token, apps = token_app.split(':')
            puts "token, apps: #{token}, #{apps}"
            if token.present? && apps.present?
              apps_list = (apps&.split(',')&.select { |v| v&.strip&.presence })&.compact
              puts "apps_list: #{apps_list}"
              if apps_list.present?
                apps_list.each { |app| total_apps[app] = token }
                puts "total_apps: #{total_apps}"
              end
            end
          end
        end
      end
    end || {}

    puts "app_tokens: #{@app_tokens}"

    super
  end

  def shutdown
    super
  end

  def client
    @_socket ||= if @use_ssl
      context    = OpenSSL::SSL::SSLContext.new
      socket     = TCPSocket.new SSL_HOST, @port
      ssl_client = OpenSSL::SSL::SSLSocket.new socket, context

      ssl_client.connect
    else
      if @protocol == 'tcp'
        TCPSocket.new NO_SSL_HOST, @port
      else
        udp_client = UDPSocket.new
        udp_client.connect NO_SSL_HOST, @port

        udp_client
      end
    end
  end

  # This method is called when an event reaches Fluentd.
  def format(tag, time, record)
    return [tag, record].to_msgpack
  end

  # NOTE! This method is called by internal thread, not Fluentd's main thread. So IO wait doesn't affect other plugins.
  def write(chunk)
    return if @token.blank?

    le_app_token = nil

    chunk.msgpack_each do |tag, record|
      next unless record.is_a? Hash

      message = if @use_json
        record.to_json
      else
        r = record.dup
        r.merge!({ "tag" => tag }) if tag.present?
        # main message
        msg = (r.delete('message')&.to_s&.rstrip || '')
        # time
        t = if r['time'].is_a?(String)
          Time.parse(r['time']).strftime('%Y-%m-%dT%H:%M:%S.%6N%:z')
        elsif r['time'].is_a?(Time)
          r['time'].strftime('%Y-%m-%dT%H:%M:%S.%6N%:z')
        else
          ''
        end
        # application & role
        app, role = if r['kubernetes_pod'].is_a?(String) && (fullapp = r['kubernetes_pod'].split('-')).present?
          [fullapp[0], fullapp[1..fullapp.size-1].join('-')]
        else
          [nil, nil]
        end
        # custom prefix built from application and role
        prefix = if app.present? && role.present? && t.present?
          le_app_token = @app_tokens[app]
          pid = '<000>0'
          spacer = ' - - '
          "#{pid} #{t} #{app} #{role} #{spacer} "
        else
          ""
        end
        # extra tags
        tags = r.map{ |k,v| "#{k}: #{v}" }.join(', ')
        # final message
        prefix + msg + (tags.present? && msg.present? ? ", " + tags : tags)
      end

      send_logentries(le_app_token || @token, message)
    end
  end

  def send_logentries(token, data)
    retries = 0
    begin
      client.write("#{token} #{data} \n")
    rescue Errno::EMSGSIZE
      str_length = data.length
      send_logentries(token, data[0..str_length/2])
      send_logentries(token, data[(str_length/2)+1..str_length])

      log.warn "Message Too Long, re-sending it in two part..."
    rescue => e
      if retries < @max_retries
        retries += 1
        @_socket = nil
        log.warn "Could not push logs to Logentries, resetting connection and trying again. #{e.message}"
        sleep 5**retries
        retry
      end
      raise ConnectionFailure, "Could not push logs to Logentries after #{retries} retries. #{e.message}"
    end
  end

end
