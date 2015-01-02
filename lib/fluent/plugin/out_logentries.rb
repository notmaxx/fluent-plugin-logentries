require 'socket'
require 'YAML'

class LogentriesOutput < Fluent::BufferedOutput
  class ConnectionFailure < StandardError; end
  # First, register the plugin. NAME is the name of this plugin
  # and identifies the plugin in the configuration file.
  Fluent::Plugin.register_output('logentries', self)

  config_param :host, :string
  config_param :port, :integer, :default => 80
  config_param :path, :string
  config_param :max_retries, :integer, :default => 3
  config_param :tag_access_log :string, :default => 'logs-access'
  config_param :tag_error_log :string, :default => 'logs-error'

  def configure(conf)
    super
  end

  def start
    super
  end

  def shutdown
    super
  end

  def client
    @_socket ||= TCPSocket.new @host, @port
  end

  # This method is called when an event reaches Fluentd.
  def format(tag, time, record)
    return [tag, record].to_msgpack
  end

  # Scan a given directory for logentries tokens
  def generate_token(path)
    tokens = {}

    Dir[path + "*.token"].each do |file|
      key = File.basename(file, ".token") # Remove path/extension from filename
      tokens[key] = YAML::load_file(file)
    end

    tokens
  end

  # returns the correct token to use for a given tag / Records
  def get_token(tag, record, tokens)
    tag    ||= ""
    record ||= ""

    tokens.each do |key, value|
      if tag.index(key) != nil || record.index(key) != nil then
        if(value != Hash)
          return value
        else
          case tag
          when @tag_access_log
            return value['access']
          when @tag_error_log
            return value['error']
          else
            return value['app']
          end
      end
    end

    return nil
  end

  # NOTE! This method is called by internal thread, not Fluentd's main thread. So IO wait doesn't affect other plugins.
  def write(chunk)
    tokens = generate_token(@path)

    chunk.msgpack_each do |tag, record|
      next unless record.is_a? Hash

      token = get_token(tag, record, tokens)
      next if token.nil?

      if record.has_key?("message")
        send_logentries(record["message"] + ' ' + token)
      end
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
