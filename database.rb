require 'pg'
require 'date'

class SessionHandler
  def initialize
    @db = Database.new
    @last_session = @db.get_last_session
  end

  def start_session
    if last_session_ended?
      start_new_session
      puts 'New Session Started'
      output_todays_data
      output_time_since_last_session_ended
    else
      last_session_not_ended
      puts 'A NEW SESSION HAS NOT BEEN STARTED YET'
    end
  end

  def end_session
    if @last_session['end_time'] == nil
      @db.end_session(@last_session['session_id'])
      puts 'Session Ended'
      output_todays_data
    else
      no_session_started_yet #FINISH
    end
  end

  def output_todays_data
    todays_time = @db.time_over_number_of_days(1)
    days_this_week = Date.today.cwday
    this_weeks_time = @db.time_over_number_of_days(days_this_week)

    puts "todays total time is #{format_time(todays_time)}"
    puts "this week's total time is #{format_time(this_weeks_time)}"
  end

  def test_it
    output_time_since_last_session_ended
  end

  private

  def last_session_ended?
    !!@last_session['end_time']
  end

  def start_new_session
    if Date.today.to_s == @last_session['day']
      @db.new_session(@last_session['day_id'])
    else
      @db.new_session_on_new_day
    end
  end

  def last_session_not_ended
    answer = ''
    loop do
      answer = prompt_for_how_to_handle
      break if answer == 'DELETE' || valid_time?(answer)
      puts "**- COULD NOT UNDERSTAND RESPONSE #{answer} - Try Again"
    end

    if answer == 'DELETE'
      @db.delete_session(@last_session['session_id'])
      puts 'Previous start time removed'
    else
      time = format_time_for_input(answer)
      @db.change_end_time(@last_session['session_id'], time)
      puts 'Last Session updated - ' +
           "#{format_time(@last_session['start_time'], twelve_hour: true)} - " +
           "#{format_time(time, twelve_hour: true)}"
    end
  end

  def prompt_for_how_to_handle
    start_time = format_time(@last_session['start_time'], twelve_hour: true)
    puts 'The previous session did not end'
    puts "The last session started at #{start_time}"
    puts '-' * 40
    puts 'Enter a end time as 00:00(AM/PM) or DELETE to remove this session'
    gets.chomp
  end

  def no_session_started_yet
    puts 'There is no session to end'
    answer = ''
    loop do
      puts 'Would you like to insert a session that ends now? (y/n)'
      answer = gets.chomp.downcase[0]
      break if ['y', 'n'].include?(answer)
      puts 'Enter either "y" or "n"'
    end

    if answer == 'n'
      puts 'OK! Goodbye!'
    else
      start_time = prompt_for_start_time
      insert_session_ending_now(start_time)
      puts 'Session Added!'
    end
    output_todays_data
  end

  def prompt_for_start_time
    time = ''
    loop do
      puts 'What should the start time be? enter as 00:00(AM/PM)'
      time = gets.chomp
      break if valid_time?(time)
      puts "COULD NOT VALIDATE TIME - #{time} - Try again"
    end
    format_time_for_input(time);
  end

  def insert_session_ending_now(start_time)
    start_new_session
    @last_session = @db.get_last_session
    @db.end_session(@last_session['session_id'])
    @db.change_start_time(@last_session['session_id'], start_time)
  end

  def valid_time?(time)
    !!time.match(/^\d\d?:\d\d(am|pm)/i)
  end

  def format_time_for_input(time)
    time_data = time.match(/(\d\d?):(\d\d)(am|pm)/i)
    hours, minutes, am_or_pm = time_data[1..3]

    hours = hours.to_i
    hours += 12 if am_or_pm.downcase == 'pm'
    hours = hours - 12 if hours % 12 == 0
    hours.to_s + ':' + minutes
  end

  def format_time(time, twelve_hour: false)
    hours, minutes, seconds = time.split(':')
    am_or_pm = ''
    if twelve_hour
      am_or_pm = hours.to_i >= 12 ? 'PM' : 'AM'
      hours = hours.to_i % 12
      hours = 12 if hours == 0
    end

    hours.to_s + ':' + minutes + am_or_pm
  end

  def output_time_since_last_session_ended
    if Date.today.to_s == @last_session['day']
      last_end_time = @last_session['end_time'].split('.').first

      current_time = Time.now.strftime("%H:%M:%S")
      time_difference = calculate_time_difference(last_end_time, current_time)

      puts "Time between sessions: #{format_time(time_difference)}"
    else
      puts "This is today's first session"
    end
  end

  def calculate_time_difference(start_time, stop_time)
    difference_in_seconds =
      time_in_seconds(stop_time) - time_in_seconds(start_time)

    minutes, seconds = difference_in_seconds.divmod(60)
    hours, minutes = minutes.divmod(60)

    "#{hours}:#{minutes}:#{seconds}"
  end

  def time_in_seconds(time)
    hours, minutes, seconds = time.split(':').map(&:to_i)
    minutes += hours * 60
    seconds + (minutes * 60)
  end
end

class Database
  def initialize
    @db = PG.connect( dbname: 'time_tracking' )
  end

  def get_last_session
    result = @db.exec_params('SELECT days.*, sessions.*
                               FROM days JOIN sessions
                                  ON days.day_id = sessions.day_id
                               ORDER BY sessions.session_id DESC
                               LIMIT 1;')

    result[0]
  end

  def new_session(day_id)
    @db.exec_params('INSERT INTO sessions (day_id) VALUES ($1)', [day_id]);
  end

  def new_session_on_new_day
    @db.exec('INSERT INTO days DEFAULT VALUES')
    new_day = @db.exec('SELECT day_id FROM DAYS ORDER BY day_id DESC')[0]
    new_session(new_day['day_id'])
  end

  def end_session(session_id)
    sql = 'UPDATE sessions SET end_time = CURRENT_TIME
           WHERE session_id = $1'
    @db.exec_params(sql, [session_id])
  end

  def time_over_number_of_days(number_of_days)
    sql = "SELECT sum(end_time - start_time)
             FROM sessions
             JOIN days ON days.day_id = sessions.day_id
            WHERE days.day > CURRENT_DATE - $1::integer
              AND sessions.end_time IS NOT NULL"
    result = @db.exec_params(sql, [number_of_days])
    result[0]['sum'] || '00:00'
  end

  def change_end_time(session_id, end_time)
    sql = 'UPDATE sessions SET end_time = $1
            WHERE session_id = $2;'
    @db.exec_params(sql, [end_time, session_id])
  end

  def delete_session(session_id)
    sql = 'DELETE FROM sessions WHERE session_id = $1'
    @db.exec_params(sql, [session_id])
  end

  def change_start_time(session_id, start_time)
    sql = 'UPDATE sessions SET start_time = $1
            WHERE sessions.session_id = $2'
    @db.exec_params(sql, [start_time, session_id])
  end
end
