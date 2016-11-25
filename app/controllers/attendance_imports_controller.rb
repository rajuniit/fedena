#Fedena
#Copyright 2011 Foradian Technologies Private Limited
#
#This product includes software developed at
#Project Fedena - http://www.projectfedena.org/
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.

class AttendanceImportsController < ApplicationController
  before_filter :login_required
  before_filter :default_time_zone_present_time


  def index

  end


  def new

  end

  def create
    upload = params[:uploadform]
    name =  Time.new.to_i.to_s + upload['datafile'].original_filename
    directory = "public/uploads/attendance"
    path = File.join(directory, name)
    File.open(path, "wb") { |f| f.write(upload['datafile'].read) }
    sms = Delayed::Job.enqueue(OnnorokomAttendanceManager.new(path))
    flash[:notice] = "#{t('attendance_flash_1')}"
    redirect_to :controller => "attendance_imports", :action => "new"
  end


end