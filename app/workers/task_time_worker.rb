require 'sidekiq'
require 'sidekiq-scheduler'

class TaskTimeWorker
  include Sidekiq::Worker

  sidekiq_options queue: "task_time", retry: false
  # schedule = []
  def perform
    time = Time.new
    selectTime = time.strftime("%Y-%m-%d %H:%M")
    time = time + 60
    selectTime1 = time.strftime("%Y-%m-%d %H:%M")
    timer_task = nil
    timer_task = TimerTask.lock.all.where('start_date between ? and ? and status= 1', selectTime, selectTime1).first
    if timer_task.nil?
      timer_task = TimerTask.lock.all.where("start_date <= ? and end_date >= ? and status= 1 and cron_type = 'cron'", selectTime, selectTime1).first
    end
    Sidekiq.logger.info(timer_task.to_json)
    unless timer_task.nil?
      case timer_task.task_type
        when "push"
          Sidekiq.logger.info('------pushtimer start-----')
          Sidekiq.logger.info(timer_task.process_id)
          PushWorker.perform_async(timer_task.process_id)
          Sidekiq.logger.info( '------pushtimer end-----')

        when "notice"
          Sidekiq.logger.info('------noticetimer start-----')
          Sidekiq.logger.info(timer_task.process_id)
          NoticeWorker.perform_async(timer_task.process_id, timer_task.extra_data)
          Sidekiq.logger.info( '------noticetimer end-----')

        else
          Sidekiq.logger.info("no exist task type")
      end
      timer_task.cron_times=timer_task.cron_times-1
      if timer_task.cron_times == 0
        timer_task.status = 2
        TimeManagerWorker.perform_async(timer_task.id, false)
      end
      timer_task.save
    else
      Sidekiq.logger.info("no")
    end

  end

end
