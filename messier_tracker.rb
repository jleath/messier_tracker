# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'yaml'

require_relative 'lib/astro_calc'
include AstroCalc

before do
  session[:logs] ||= {}
  session[:user_latitude] ||= 0.0
  session[:user_longitude] ||= 0.0
  @current_time = Time.now.utc
end

helpers do
  def messier_card(messier_id, info, view)
    title = info[:name].empty? ? messier_id : "#{messier_id} - #{info[:name]}"
    log_entries = log_entries(messier_id)
    <<~CARD_HTML
      <div class="messier_card #{'tracked' unless log_entries.empty?}">
        <div class="info">
          <h1>#{title}</h1>
          <ul>
            <li>Type: #{info[:type]}</li>
            <li>Constellation: #{info[:constellation]}</li>
            <li>Apparent Magnitude:
              <span class="magnitude #{magnitude_color(info[:magnitude])}">#{info[:magnitude]}</span>
            </li>
            <li>Current Alt/Az: #{info[:altitude].to_i}° / #{info[:azimuth].to_i}°</li>
          </ul>
          <div class="log_options">
            <ul>
              <li>Logged #{log_entries.size} time#{'s' if log_entries.size != 1}</li>
              #{log_options(messier_id, view)}
            </ul>
          </div>
        </div>
        <img src="/messier_imgs/#{messier_id}.jpg">
      </div>
    CARD_HTML
  end
end

configure do
  enable :sessions
  set :session_secret, 'secret'
end

get '/' do
  @messier_data = messier_data
  erb :index
end

get '/view/:messier_id' do
  @messier_id = params[:messier_id]
  @info = messier_data(@messier_id)
  @log_entries = log_entries(@messier_id)
  erb :view_logs
end

get '/add/:messier_id' do
  @messier_id = params[:messier_id]
  @info = messier_data(@messier_id)
  erb :add_new
end

post '/add/:messier_id' do
  @messier_id = params[:messier_id]
  @info = messier_data(@messier_id)
  log_entry = params[:log_entry]
  if log_entry.nil? || log_entry.empty?
    session[:message] = 'You cannot submit an empty log.'
    status 422
    erb :add_new
  else
    add_log_entry(@messier_id, log_entry)
    session[:message] = "Entry added for #{@messier_id}"
    redirect "/view/#{@messier_id}"
  end
end

post '/edit/:messier_id/log/:entry_index' do
  @messier_id = params[:messier_id]
  log_entry_index = params[:entry_index].to_i
  new_entry = params[:new_entry]
  @log_entries = log_entries(@messier_id)
  @info = messier_data(@messier_id)
  # check for nonexistent entry
  if @log_entries.empty?
    session[:message] = "Log entry #{log_entry_index} for #{@messier_id} does not exist."
    status 422
    erb :view_logs
  # check for attempt to save unmodified log
  elsif new_entry == @log_entries[log_entry_index]
    session[:message] = "No changes made to log entry #{log_entry_index} for #{@messier_id}."
    status 422
    erb :view_logs
  else
    @log_entries[log_entry_index] = new_entry
    session[:message] = "Log entry #{log_entry_index} for #{@messier_id} has been edited."
    redirect "/view/#{@messier_id}"
  end
end

post '/delete/:messier_id/log/:entry_index' do
  @messier_id = params[:messier_id]
  log_entry_index = params[:entry_index].to_i
  @log_entries = log_entries(@messier_id)
  if @log_entries[log_entry_index]
    @log_entries.delete_at(log_entry_index)
    session[:message] = "Log entry #{log_entry_index} for #{@messier_id} has been deleted."
    redirect "/view/#{@messier_id}"
  else
    session[:message] = "Log entry #{log_entry_index} for #{@messier_id} does not exist."
    status 422
    @info = messier_data(@messier_id)
    erb :view_logs
  end
end

post '/setcoords' do
  session[:user_latitude] = params[:new_latitude].to_f
  session[:user_longitude] = params[:new_longitude].to_f
  redirect back
end

def image_path
  File.expand_path('../messier_imgs/', __FILE__)
end

def messier_data_path
  File.expand_path('../data/messier_object_data.yml', __FILE__)
end

def messier_data(messier_id = nil)
  all_data = YAML.load_file(messier_data_path)
  dt = @current_time
  lat = session[:user_latitude]
  lon = session[:user_longitude]
  all_data.each do |id, info|
    ra = info[:ascension]
    dc = info[:declination]
    alt, az = AstroCalc::calculate_alt_az(ra, dc, dt, lat, lon)
    info[:altitude] = alt
    info[:azimuth] = az
  end
  messier_id.nil? ? all_data : all_data[messier_id]
end

def log_entries(messier_id)
  session[:logs][messier_id] ||= []
  session[:logs][messier_id]
end

def add_log_entry(messier_id, entry_text, entry_number = nil)
  if entry_number.nil?
    log_entries(messier_id).append(entry_text)
  else
    log_entries(messier_id)[entry_number] = entry_text
  end
end

def magnitude_color(magnitude)
  case magnitude
  when 0...3 then 'low_mag'
  when 3...6 then 'midlow_mag'
  when 6...9 then 'midhigh_mag'
  when 9...12 then 'high_mag'
  end
end

def log_options(messier_id, view)
  view_list_string = "<li><a href=\"view/#{messier_id}\">View logs</a></li>"
  new_list_string = "<li><a href=\"/add/#{messier_id}\">Add new log</a></li>"
  case view
  when :index then "#{view_list_string}\n#{new_list_string}"
  when :view then new_list_string
  when :add then view_list_string
  end
end
