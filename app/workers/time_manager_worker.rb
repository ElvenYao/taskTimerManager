require 'sidekiq'
require 'sidekiq-scheduler'

class TimeManagerWorker
  include Sidekiq::Worker

  sidekiq_options queue: "time_manager", retry: false

  def perform(id=nil, setOnline=false, type="at", crontime=nil)
    unless id.blank?
      if setOnline
        Sidekiq.logger.info("===create task: task#{id}===")
        Sidekiq.set_schedule("task#{id}", { type=> crontime, 'class' => 'TaskTimeWorker', 'queue' => 'task_time'})
      else
        Sidekiq.logger.info("===delete task: task#{id}===")
        Sidekiq.set_schedule("task#{id}", { 'enabled' => false})
      end
    else
      Sidekiq.logger.info("=======clear outtime start========")
      nowday = Time.new.strftime("%Y-%m-%d %H:%M")
      delete_timer_task = TimerTask.all.where("end_date <= ? and status= 1 and cron_type = 'cron'", nowday).to_a
      delete_timer_task.each do |task|
          Sidekiq.logger.info("task#{task.id} time out")
          Sidekiq.set_schedule("task#{task.id}", { 'enabled' => false})
          task.status = 3
          task.save
      end
      Sidekiq.logger.info("=======clear outtime end========")
      Sidekiq.logger.info("Clear all outtime")

      Sidekiq.logger.info("=======restart tasks start========")
      restart_timer_task = TimerTask.all.where("status= 1").to_a
      restart_timer_task.each do |r_task|
        self.perform(r_task.id, true, r_task.cron_type, r_task.cron_str)
        Sidekiq.logger.info("task#{r_task.id} restart")
      end
      Sidekiq.logger.info("=======restart tasks start========")

    end
    Sidekiq.logger.info(Sidekiq.get_schedule)
  end

end
