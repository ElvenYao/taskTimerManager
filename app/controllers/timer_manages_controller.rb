module GameManage
  class TimerManagesController < ApplicationController
    before_action :init_options

    def index
      # @timer_tasks = TimerTask.all
      @timer_tasks = TimerTask.page(params[:page]).order("id desc").per(20)
    end

    def new
      @TimerTask = TimerTask.new
    end

    def edit
      @TimerTask = TimerTask.find(params[:id])
    end

    def create
      data,extra_data = data_params()
      hash = {
          :status => 0,
          :created_at => Time.now,
          :extra_data => extra_data
      }.merge!(data)
      timertask = TimerTask.create(hash)
      flash[:success] = "new #{timertask.task_type} task"
      redirect_to :action => :index
    end

    def update
      @TimerTask = TimerTask.find(params[:id])
      data,extra_data = data_params()
      hash = {
          :updated_at => Time.now,
          :extra_data => extra_data
      }.merge!(data)
      @TimerTask.update_attributes(hash)
      redirect_to action: :index
    end

    def switch
      @timer_task = TimerTask.find(params[:id])
      if @timer_task[:status] == TimerTask::TimerTaskStatus::PREPARE
        setOnline = true
        @timer_task[:status] = 1
        msg = ' ON'
      elsif @timer_task[:status] == TimerTask::TimerTaskStatus::RUNING
        setOnline = false
        @timer_task[:status] = 0
        msg = ' OFF'
      end
      @timer_task.save
      result = @timer_task.operate(setOnline)
      if result
        flash[:success] = "task #{@timer_task[:id]}#{msg}"
      else
        flash[:warning] = "task error"
      end
      redirect_to action: :index
    end

    def get_task
      dataJson = ""
      case params[:type]
        when "push"
          dataJson = GameManage::Push.select(:id,:name).where("send_type = 1 and status = 0").all
        when "notice"
          dataJson = GameManage::Notice.select(:id,:name).where("flags = 0").all
      end
      render :json =>{:data => dataJson}
    end

    private
    def data_params
      data_params = params[:timer_task]
      data_params[:start_date] = Time.parse(data_params[:start_date]).strftime("%Y-%m-%d %H:%M:%S")
      extra_data = ""
      if data_params[:task_type] == "notice"
        extra_data = current_target.to_json
      end
      if data_params[:cron_type] == "at"
        data_params[:cron_str] = (Time.parse(data_params[:start_date])-3600*8).strftime("%Y-%m-%d %H:%M:%S").gsub('-', '/')
      end
      return data_params, extra_data
    end

    def to_utc_str(time)
      DateTime.strptime(time,'%Y-%m-%d %H:%M:%S').utc
    end

    def init_options
    end
  end
end