# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'minitest/reporters'
require 'rack/test'

require_relative '../messier_tracker'

Minitest::Reporters.use!

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def existing_logs(messier_id, num_logs)
    logs = []
    num_logs.times do |index|
      logs.append("test#{index}")
    end
    { 'rack.session' => { logs: { messier_id => logs } } }
  end

  def session
    last_request.env['rack.session']
  end

  def test_index
    get '/'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'M1'
    assert_includes last_response.body, 'View logs'
    assert_includes last_response.body, 'Add new log'
    assert_equal 110, last_response.body.scan(%r{<a href="view/.*?">View logs</a>}).size
  end

  def test_view_empty_log
    get '/view/M33'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'M33'
    assert_includes last_response.body, 'Logged 0 times'
    assert_includes last_response.body, 'Add new log'
    refute_includes last_response.body, 'View logs'
  end

  def test_view_log
    get '/view/M33', {}, existing_logs('M33', 1)
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'test0'
    assert_includes last_response.body, 'Logged 1 time'
    refute_includes last_response.body, 'View logs'

    get '/view/M33', {}, existing_logs('M33', 2)
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'test0'
    assert_includes last_response.body, 'test1'
    assert_includes last_response.body, 'Logged 2 times'
  end

  def test_add_log_form_no_entries
    get '/add/M33'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'M33'
    assert_includes last_response.body, 'Observation Log:'
    assert_includes last_response.body, '<button type="submit">Save Log</button>'
  end

  def test_add_log_form_existing_logs
    get '/add/M33', {}, existing_logs('M33', 2)
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Logged 2 times'
    assert_includes last_response.body, 'View logs'
    refute_includes last_response.body, 'Add new log'
  end

  def test_submit_empty_log
    post '/add/M33', { 'log_entry' => '' }
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'You cannot submit an empty log.'
    refute_includes last_response.body, 'messier_card tracked'

    post '/add/M33', { 'log_entry' => nil }
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'You cannot submit an empty log.'
    refute_includes last_response.body, 'messier_card tracked'
  end

  def test_submit_valid_log
    post '/add/M33', { 'log_entry' => 'test' }
    assert_equal 302, last_response.status
    assert_equal 'Entry added for M33', session[:message]
    assert_equal 'http://example.org/view/M33', last_response['Location']

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'test'
    assert_includes last_response.body, 'messier_card tracked'
  end

  def test_delete_log
    post '/delete/M33/log/0', {}, existing_logs('M33', 1)
    assert_equal 302, last_response.status
    assert_equal 'http://example.org/view/M33', last_response['Location']

    get last_response['Location']
    assert_equal 200, last_response.status
    refute_includes last_response.body, 'test0'
    assert_includes last_response.body, 'Logged 0 times'
    refute_includes last_response.body, 'messier_card tracked'
  end

  def test_delete_nonexistent_log
    post '/delete/M33/log/0'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Log entry 0 for M33 does not exist.'
    assert_includes last_response.body, 'Logged 0 times'
  end

  def test_edit_log
    post '/edit/M33/log/0', { 'new_entry' => 'modified' }, existing_logs('M33', 3)
    assert_equal 302, last_response.status
    assert_equal 'http://example.org/view/M33', last_response['Location']
    assert_equal 'Log entry 0 for M33 has been edited.', session[:message]

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'modified'
    assert_includes last_response.body, 'Logged 3 times'
  end

  def test_edit_log_no_changes
    post '/edit/M33/log/0', { 'new_entry' => 'test0' }, existing_logs('M33', 1)
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'No changes made to log entry 0 for M33'
  end

  def test_edit_nonexistent_log
    post '/edit/M33/log/0', { 'new_entry' => 'test0' }
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Log entry 0 for M33 does not exist.'
  end
end
