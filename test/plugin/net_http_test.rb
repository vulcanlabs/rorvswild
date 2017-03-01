require File.expand_path("#{File.dirname(__FILE__)}/../helper")

require "net/http"

class RorVsWild::Plugin::NetHttpTest < Minitest::Test
  def test_callback
    client.measure_block("test") { Net::HTTP.get("ruby-lang.org", "/index.html") }
    assert_equal(1, client.send(:sections).size)
    assert_equal(1, client.send(:sections)[0].calls)
    assert_equal("http", client.send(:sections)[0].kind)
    assert_match("GET http://ruby-lang.org/index.html", client.send(:sections)[0].command)
  end

  def test_callback_with_https
    client.measure_block("test") { Net::HTTP.get(URI("https://www.ruby-lang.org/index.html")) }
    assert_match("GET https://www.ruby-lang.org/index.html", client.send(:sections)[0].command)
    assert_equal("http", client.send(:sections)[0].kind)
  end

  def test_nested_query_because_net_http_request_is_recursive_when_connection_is_not_started
    client.measure_block("test") do
      uri = URI("http://www.ruby-lang.org/index.html")
      http = Net::HTTP.new(uri.host, uri.port)
      http.request(Net::HTTP::Get.new(uri.path))
    end
    # TODO: Find a way to count only 1 time the request
    assert_equal(2, client.send(:sections)[0].calls)
  end

  private

  def client
    @client ||= initialize_client(app_root: "/rails/root")
  end

  def initialize_client(options = {})
    client = RorVsWild::Client.new(options)
    client.stubs(:post_request)
    client.stubs(:post_job)
    client
  end
end
