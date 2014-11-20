# -*- coding: utf-8 -*-

require 'mechanize'
require 'cgi'
require 'niconico/version'

class Niconico
  URL = {
    top: 'http://www.nicovideo.jp/',
    login: 'https://secure.nicovideo.jp/secure/login?site=niconico',
    watch: 'http://www.nicovideo.jp/watch/',
    getflv: 'http://flapi.nicovideo.jp/api/getflv'
  }

  TEST_VIDEO_ID = "sm9"

  attr_reader :agent

  def logged_in?; @logged_in; end
  alias logined logged_in?

  def initialize(*args)
    case args.size
    when 2
      @mail, @pass = args
    when 1
      @token = args.first
    else
      raise ArgumentError, "wrong number of arguments (#{args.size} for 1..2)"
    end

    @logged_in = false

    @agent = Mechanize.new.tap do |agent|
      agent.user_agent = "Niconico.gem (#{Niconico::VERSION}, https://github.com/sorah/niconico)"
      agent.ssl_version = 'SSLv3'

      agent.cookie_jar.add(
        HTTP::Cookie.new(
          domain: '.nicovideo.jp', path: '/',
          name: 'lang', value: 'ja-jp',
        )
      )
    end
  end

  def login(force=false)
    return false if !force && @logged_in

    if @token
      login_with_token
    elsif @mail && @pass
      login_with_email
    else
      raise 'huh? (may be bug)'
    end
  end

  def inspect
    "#<Niconico: #{@mail || '(token)'}, #{@logged_in ? "" : "not "}logged in>"
  end

  def token
    return @token if @token
    login unless logged_in?

    @token = agent.cookie_jar.each('https://www.nicovideo.jp').find{|_| _.name == 'user_session' }.value
  end

  class LoginError < StandardError; end

  private

  def login_with_email
    page = @agent.post(URL[:login], 'mail' => @mail, 'password' => @pass)

    raise LoginError, "Failed to login (x-niconico-authflag is 0)" if page.header["x-niconico-authflag"] == '0'
    @logged_in = true
  end

  def login_with_token
    @agent.cookie_jar.add(
      HTTP::Cookie.new(
        domain: '.nicovideo.jp', path: '/',
        name: 'user_session', value: @token
      )
    )

    page = @agent.get(URL[:top])
    raise LoginError, "Failed to login (x-niconico-authflag is 0)" if page.header["x-niconico-authflag"] == '0'

    @logged_in = true
  end

end

require 'niconico/video'
require 'niconico/mylist'
require 'niconico/ranking'
require 'niconico/channel'
require 'niconico/live'
