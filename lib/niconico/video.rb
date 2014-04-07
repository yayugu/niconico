# -*- coding: utf-8 -*-
require 'json'

class Niconico
  def video(video_id)
    login unless @logined
    Video.new(self, video_id)
  end

  class Video
    DEFERRABLES = [:id, :title, :url, :video_url, :type, :tags, :mylist_comment, :description, :description_raw]
    DEFERRABLES_VAR = DEFERRABLES.map{|k| :"@#{k}" }

    DEFERRABLES.zip(DEFERRABLES_VAR).each do |(k,i)|
      define_method(k) do
        instance_variable_get(i) || (get && instance_variable_get(i))
      end
    end

    def initialize(parent, video_id, defer=nil)
      @parent = parent
      @agent = parent.agent
      @fetched = false
      @thread_id = @id = video_id
      @url = "#{Niconico::URL[:watch]}#{@id}"

      if defer
        defer.each do |k,v|
          next unless DEFERRABLES.include?(k)
          instance_variable_set :"@#{k}", v
        end
        @page = nil
      else
        @page = get()
      end
    end

    def economy?; @eco; end
    def fetched?; @fetched; end

    def get(options = {})
      begin
        @page = @agent.get(@url)
      rescue Mechanize::ResponseCodeError => e
        raise NotFound, "#{@id} not found" if e.message == "404 => Net::HTTPNotFound"
        raise e
      end

      if /^so/ =~ @id
        sleep 5
        @thread_id = @agent.get("#{Niconico::URL[:watch]}#{@id}").uri.path.sub(/^\/watch\//,"")
      end
      additional_params = nil
      if /^nm/ === @id && (!options.key?(:as3) || options[:as3])
        additional_params = "&as3=1"
      end
      getflv = Hash[@agent.get_file("#{Niconico::URL[:getflv]}?v=#{@thread_id}#{additional_params}").scan(/([^&]+)=([^&]+)/).map{|(k,v)| [k.to_sym,CGI.unescape(v)] }]

      if api_data = @page.at("#watchAPIDataContainer")
        video_detail = JSON.parse(api_data.text())["videoDetail"]
        @title ||= video_detail["title"] if video_detail["title"]
        @description ||= video_detail["description"] if video_detail["description"]
        @tags  ||= video_detail["tagList"].map{|e| e["tag"]}
      end

      t = @page.at("#videoTitle")
      @title ||= t.inner_text unless t.nil?
      d = @page.at("div#videoComment>div.videoDescription")
      @description ||= d.inner_html unless d.nil?

      @video_url = getflv[:url]
      @eco = !(/low$/ =~ @video_url).nil?
      @type = case @video_url.match(/^http:\/\/(.+\.)?nicovideo\.jp\/smile\?(.+?)=.*$/).to_a[2]
              when 'm'; :mp4
              when 's'; :swf
              else;     :flv
              end
      @tags ||= @page.search("#video_tags a[rel=tag]").map(&:inner_text)
      @mylist_comment ||= nil

      @fetched = true
      @page
    end

    def get_video
      @agent.get_file(@video_url)
    end

    def get_video_by_other
      {cookie: @agent.cookie_jar.cookies(URI.parse(@video_url)),
       url: @video_url}
    end

    def inspect
      "#<Niconico::Video: #{@id}.#{@type} \"#{@title}\"#{@eco ? " low":""}>"
    end

    class NotFound < StandardError; end
  end
end
