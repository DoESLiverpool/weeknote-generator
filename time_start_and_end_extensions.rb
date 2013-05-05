# A few extensions to Fixnum and Time to allow easier manipulation of
# Time objects when searching for weeknotes, etc.

class Fixnum
  def day
    self*60*60*24
  end

  def days
    self.day
  end
end

class Time
  def start_of_day
    self - (self.sec + 60*self.min + 60*60*self.hour)
  end
  
  def end_of_day
    self + (59-self.sec) + 60*(59-self.min) + 60*60*(23-self.hour)
  end
  
  def start_of_week
    self.start_of_day - (60*60*24*self.wday)
  end

  def start_of_work_week
    days_back = (self.wday == 0 ? 6 : self.wday-1)
    self.start_of_day - days_back.days
  end
  
  def end_of_week
    self.end_of_day + (6-self.wday).days
  end

  def end_of_work_week
    days_forward = (self.wday == 0 ? 0 : 7-self.wday)
    self.end_of_day + days_forward.days
  end
end
