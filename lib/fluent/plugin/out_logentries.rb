require 'socket'
require 'yaml'
require 'openssl'

class LogentriesOutput < Fluent::BufferedOutput
  class ConnectionFailure < StandardError; end
  # First, register the plugin. NAME is the name of this plugin
  # and identifies the plugin in the configuration file.
  Fluent::Plugin.register_output('logentries', self)

  config_param :use_ssl,        :bool,    :default => true
  config_param :no_ssl_port,    :integer, :default => 80
  config_param :config_path,    :string
  config_param :max_retries,    :integer, :default => 3
  config_param :tag_access_log, :string,  :default => 'logs-access'
  config_param :tag_error_log,  :string,  :default => 'logs-error'

  def configure(conf)
    super

    @tokens    = nil
    @last_edit = Time.at(0)
  end

  def start
    super
  end

  def shutdown
    super
  end

  def client
    @_socket ||= if @use_ssl
      context    = OpenSSL::SSL::SSLContext.new
      socket     = TCPSocket.new "api.logentries.com", 20000
      ssl_client = OpenSSL::SSL::SSLSocket.new socket, context

      ssl_client.connect
    else
      TCPSocket.new "data.logentries.com", @no_ssl_port
    end
  end

  # This method is called when an event reaches Fluentd.
  def format(tag, time, record)
    return [tag, record].to_msgpack
  end

  # Parse an YML file and generate a list of tokens.
  # It will only re-generate the list on changes.
  def generate_tokens_list
    begin
      edit_time = File.mtime(@config_path)

      if edit_time > @last_edit
        @tokens    = YAML::load_file(@config_path)
        @last_edit = edit_time

        log.info "Token(s) list updated."
      end
    rescue Exception => e
      log.warn "Could not load configuration. #{e.message}"
    end
  end

  # Returns the correct token to use for a given tag / records
  def get_token(tag, record)
    tag     ||= ""
    app_name = record["app_name"] || ""

    # Config Structure
    # -----------------------
    # app-name:
    #   app: TOKEN
    #   access: TOKEN (optional)
    #   error: TOKEN  (optional)
    @tokens.each do |key, value|
      if tag.index(key) != nil || app_name.index(key) != nil
        default = value['app']

        case tag
          when @tag_access_log
            return value['access'] || default
          when @tag_error_log
            return value['error']  || default

          else
            return default
        end
      end
    end

    return nil
  end

  # NOTE! This method is called by internal thread, not Fluentd's main thread. So IO wait doesn't affect other plugins.
  def write(chunk)
    generate_tokens_list()
    return unless @tokens.is_a? Hash

    chunk.msgpack_each do |tag, record|
      next unless record.is_a? Hash
      next unless record.has_key? "message"

      token = get_token(tag, record)
      next if token.nil?

      send_logentries(token + ' ' + record["message"])
    end
  end

  def send_logentries(data)
    retries = 0
    begin
      client.puts data
    rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT => e
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
