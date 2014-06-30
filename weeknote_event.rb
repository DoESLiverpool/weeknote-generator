#!/usr/bin/ruby
#
# WeeknoteEvent - simple class to help generating weeknotes blog posts
# (c) Copyright 2013 Adrian McEwen

class WeeknoteEvent
  attr_accessor :start_time, :finish_time, :html

  def initialize(start_time, finish_time, html)
    @start_time = start_time
    @finish_time = finish_time
    @html = html
  end

  def WeeknoteEvent.new_from_ical(ical_ev, next_occurrence)
    if next_occurrence.nil?
      start_time = ical_ev.start_time
      finish_time = ical_ev.finish_time
    else
      start_time = next_occurrence.start_time
      finish_time = next_occurrence.finish_time
    end
    html = "<tr>"
    # Because the %l in strftime is blank padded, if any of the hour
    # values are < 10 we'll get an extra blank space we don't want
    # So we strip them out with lstrip (ugly, but results in prettier content...)
    if Date.parse(start_time.to_s) == Date.parse(finish_time.to_s)
      # Starts and ends on the same day
      html = html + "\n<td>"+start_time.strftime("%A %d %B, ")
      html = html + start_time.strftime("%l:%M%P").lstrip+"-"
      html = html + finish_time.strftime("%l:%M%P").lstrip+"</td>"
    else
      # Multi-day event
      html = html + "\n<td>"+start_time.strftime("%A %d %B, ")
      html = html + start_time.strftime("%l:%M%P").lstrip+"-"
      html = html + finish_time.strftime("%A %d %B, ")
      html = html + finish_time.strftime("%l:%M%P").lstrip+"</td>"
    end
    html = html + "\n<td><a href=\""+ical_ev.description+"\">"+ical_ev.summary.gsub('"', '')+"</a></td>"
    html = html + "\n</tr>"
    #puts ical_ev.to_s
    WeeknoteEvent.new(start_time, finish_time, html)
  end

end

