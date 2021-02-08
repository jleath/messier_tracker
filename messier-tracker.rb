require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'yaml'

def image_path
  "/messier_imgs/"
end

before do
  session[:logs] ||= {}
end

helpers do
  def messier_data
    YAML.load_file('data/messier_object_data.yml')
  end

  def log_options(messier_number, view)
    case view
    when :index then
      <<~EOF
      <li><a href="view/#{messier_number}">View logs</a></li>
      <li><a href="/add/#{messier_number}">Add new log</a></li>
      EOF
    when :view then
      <<~EOF
      <li><a href="/add/#{messier_number}">Add new log</a></li>
      EOF
    when :add then
      <<~EOF
      <li><a href="/view/#{messier_number}">View logs</a></li>
      EOF
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

  def messier_card(number, info, view)
    title = info[:name].empty? ? number : "#{number} - #{info[:name]}"
    log_entries = session[:logs][number]
    num_log_entries = (log_entries ? log_entries.size : 0)
    <<~EOF
    <div class="messier_card #{'tracked' if num_log_entries > 0}">
      <div class="info">
        <h1>#{title}</h1>
        <ul>
          <li>Type: #{info[:type]}</li>
          <li>Constellation: #{info[:constellation]}</li>
          <li>Apparent Magnitude:
            <span class="magnitude #{magnitude_color(info[:magnitude].to_f)}">#{info[:magnitude]}</span>
          </li>
        </ul>
        <div class="log_options">
          <ul>
            <li>Logged #{num_log_entries} time#{'s' if num_log_entries != 1}</li>
            #{log_options(number, view)}
          </ul>
        </div>
      </div>
      <img src="/messier_imgs/#{number}.jpg">
    </div>
    EOF
  end
end

configure do
  enable :sessions
  set :session_secret, 'secret'
end

get '/' do
  erb :index
end

get '/view/:number' do
  @number = params[:number]
  @info = messier_data[@number]
  session[:logs][@number] ||= []
  @log_entries = session[:logs][@number]
  erb :view_logs
end

get '/add/:number' do
  @number = params[:number]
  @info = messier_data[@number]
  erb :add_new
end

post '/add/:number' do
  @number = params[:number]
  @info = messier_data[@number]
  if params[:log_entry].nil? || params[:log_entry].empty?
    session[:message] = "You cannot submit an empty log."
    status 422
    erb :add_new
  else
    session[:logs][@number] ||= []
    session[:logs][@number].append(params[:log_entry])
    session[:message] = "Entry added for #{@number}"
    redirect "/view/#{@number}"
  end
end

post '/edit/:number/log/:entry_index' do
  @number = params[:number]
  log_entry_index = params[:entry_index].to_i
  new_entry = params[:new_entry]
  @log_entries = session[:logs][@number] || []
  @info = messier_data[@number]
  # check for nonexistent entry
  if @log_entries.empty?
    session[:message] = "Log entry #{log_entry_index} for #{@number} does not exist."
    status 422
    erb :view_logs
  # check for attempt to save unmodified log
  elsif new_entry == @log_entries[log_entry_index]
    session[:message] = "No changes made to log entry #{log_entry_index} for #{@number}."
    status 422
    erb :view_logs
  else
    @log_entries[log_entry_index] = new_entry
    session[:message] = "Log entry #{log_entry_index} for #{@number} has been edited."
    redirect "/view/#{@number}"
  end
end

post '/delete/:number/log/:entry_index' do
  @number = params[:number]
  log_entry_index = params[:entry_index].to_i
  @log_entries = session[:logs][@number] || []
  if @log_entries[log_entry_index]
    @log_entries.delete_at(log_entry_index)
    session[:message] = "Log entry #{log_entry_index} for #{@number} has been deleted."
    redirect "/view/#{@number}"
  else
    session[:message] = "Log entry #{log_entry_index} for #{@number} does not exist."
    status 422
    @info = messier_data[@number]
    erb :view_logs
  end
end