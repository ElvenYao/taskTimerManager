class TimerTask < ActiveRecord::Base
  module TimerTaskStatus
    PREPARE = 0
    RUNING = 1
    FINISHED = 2
    TIMEOUT = 3
  end

  def operate(setOnline)
    unless self.id.nil? && self.cron_type.nil? && self.cron_str.nil?
      TimeManagerWorker.perform_async(self.id, setOnline, self.cron_type, self.cron_str)
      return true
    else
      return false
    end
  end
end
