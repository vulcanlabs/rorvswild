require File.expand_path("#{File.dirname(__FILE__)}/../helper")

require "redis"

class RorVsWild::Plugin::RedisTest < Minitest::Test
  def test_callback
    client.measure_code("::Redis.new.get('foo')")
    assert_equal(1, client.send(:queries).size)
    assert_equal("redis", client.send(:queries)[0][:kind])
    assert_equal("get foo", client.send(:queries)[0][:command])
  end

  def test_callback_with_pipeline
    skip
    client.measure_block("pipeline") do
      redis = ::Redis.new
      redis.get("foo")
      redis.set("foo", "bar")
    end
    assert_equal(2, client.send(:queries).size)
    assert_equal("redis", client.send(:queries)[0][:kind])
    assert_equal("get foo", client.send(:queries)[0][:command])
    assert_equal("set foo bar", client.send(:queries)[1][:command])
  end

  def test_commands_to_string_hide_auth_password
    assert_equal("auth *****", RorVsWild::Plugin::Redis.commands_to_string([[:auth, "SECRET"]]))
  end

  private

  def client
    @client ||= initialize_client(app_root: "/rails/root")
  end

  def initialize_client(options = {})
    client ||= RorVsWild::Client.new(options)
    client.stubs(:post_request)
    client.stubs(:post_job)
    client
  end
end