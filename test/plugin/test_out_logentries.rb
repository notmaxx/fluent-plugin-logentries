require 'test/unit'

require 'fluent/test'
require 'fluent/plugin/out_logentries'


class LogentriesOutput < Test::Unit::TestCase
  def setup
    Fluent::Test.setup

    @driver = nil
  end

  def driver(tag='test', conf='')
    @driver ||= Fluent::Test::BufferedOutputTestDriver.new(Fluent::LogentriesOutput, tag).configure(conf)
  end

  def instance
    config = %{
      use_ssl          false
      port             777
      protocol         udp
      config_path      /tmp/config.yml
      tag_access_log   access
      tag_error_log    error
    }

    driver('test', config).instance
  end

  def test_configure
    config = %{
      use_ssl          false
      port             777
      protocol         udp
      config_path      /tmp/config.yml
      tag_access_log   access
      tag_error_log    error
    }
    instance = driver('test', config).instance

    assert_equal false, instance.use_ssl
    assert_equal 777, instance.port
    assert_equal 'udp', instance.protocol
    assert_equal '/tmp/config.yml', instance.config_path
    assert_equal 'access', instance.tag_access_log
    assert_equal 'error', instance.tag_error_log
  end

  def test_load_config
    instance.generate_tokens_list
  end

  def test_get_token_simple
    record = {
      "app_name" => "first-app",
      "message"  => '{ "error" : 1}',
      "tag"      => 'app'
    }

    instance.generate_tokens_list
    res = instance.get_token('tag', record)

    assert_equal '000-00-000', res
  end

  def test_get_token_simple_access
    record = {
      "app_name" => "secondApp",
      "message"  => '{ "error" : 1}'
    }

    instance.generate_tokens_list
    res = instance.get_token('access', record)

    assert_equal '111-00-111', res
  end

  def test_get_token_env_access
    record = {
      "app_name" => "Bar--223--test",
      "message"  => '{ "error" : 1}'
    }

    instance.generate_tokens_list
    res = instance.get_token('access', record)

    assert_equal '444-11-111', res
  end

end
