# Configure your SMS API settings
require 'net/http'
require 'yaml'
require 'translator'
require 'savon'

class OnnorokomAttendanceManager
  attr_accessor :attendance_file,
                :present_student_parent_message,
                :present_student_parent_recipients,
                :absent_student_parent_message,
                :absent_student_parent_recipients

  def initialize(attendance_file)
    @attendance_file = attendance_file
    @present_student_parent_message = "Thank you, Today Your child Attend School"
    @absent_student_parent_message = "Sorry!, Today Your child don't Attend School"

    #Process to get receipient
    batches = Batch.active

    @present_student_parent_recipients = []
    @absent_student_parent_recipients = []

    @student_ids = []

    file = File.new(@attendance_file, "r")
    while (line = file.gets)
      str_arr = line.split(",")
      id = str_arr[3].delete('"').to_i unless str_arr[3].nil?
      @student_ids.push id unless id.nil?
    end
    file.close

    sms_setting = SmsSetting.new()
    batches.each do |batch|
      batch_students = batch.students
      batch_students.each do |student|
        if @student_ids.include? student.id
          if student.is_sms_enabled
            if sms_setting.parent_sms_active
              guardian = student.immediate_contact
              unless guardian.nil?
                @present_student_parent_recipients.push guardian.mobile_phone unless (guardian.mobile_phone.nil? or guardian.mobile_phone == "")
              end
            end
          end
        else
          attendance_data = Hash.new
          attendance_data["student_id"] = student.id
          attendance_data["month_date"] = Time.new.strftime("%Y-%m-%d")
          attendance_data["batch_id"] = batch.id
          attendance_data["reason"] = "Unknown"
          attendance_data["forenoon"] = 1
          attendance_data["afternoon"] = 1

          @absentee = Attendance.new(attendance_data)
          @absentee.save
          if student.is_sms_enabled
            if sms_setting.parent_sms_active
              guardian = student.immediate_contact
              unless guardian.nil?
                @absent_student_parent_recipients.push guardian.mobile_phone unless (guardian.mobile_phone.nil? or guardian.mobile_phone == "")
              end
            end
          end
        end
      end
    end

    @config = SmsSetting.get_onnorokom_sms_config
    unless @config.blank?
      @sendername = @config['sms_settings']['sendername']
      @sms_url = @config['sms_settings']['host_url']
      @username = @config['sms_settings']['username']
      @password = @config['sms_settings']['password']
      @success_code = @config['sms_settings']['success_code']
      @savon_client = Savon::Client.new do
        wsdl.document = "http://api2.onnorokomsms.com/sendsms.asmx?wsdl"
      end
    end
  end

  def perform
    if @config.present?
      message_log = SmsMessage.new(:body => @message)
      message_log.save
      begin
        numbers = @present_student_parent_recipients.join(',')
        response = send_sms(@present_student_parent_message, numbers).to_hash
        if response.empty?
          message_log.sms_logs.create(:mobile => numbers, :gateway_response => response.to_s)
          sms_count = Configuration.find_by_config_key("TotalSmsCount")
          new_count = sms_count.config_value.to_i + @absent_student_parent_recipients.count
          sms_count.update_attributes(:config_value => new_count)
        end
      rescue Savon::SOAP::Fault => e
        message_log.sms_logs.create(:mobile => numbers, :gateway_response => e.to_s)
      rescue Savon::Error => e
        message_log.sms_logs.create(:mobile => numbers, :gateway_response => e.to_s)
      end


      begin
        numbers = @absent_student_parent_recipients.join(',')
        response = send_sms(@present_student_parent_message, numbers).to_hash
        if response
          message_log.sms_logs.create(:mobile => numbers, :gateway_response => response.to_s)
          sms_count = Configuration.find_by_config_key("TotalSmsCount")
          new_count = sms_count.config_value.to_i + @absent_student_parent_recipients.count
          sms_count.update_attributes(:config_value => new_count)
        end
      rescue Savon::SOAP::Fault => e
        message_log.sms_logs.create(:mobile => numbers, :gateway_response => e.message)
      rescue Savon::Error => e
        message_log.sms_logs.create(:mobile => numbers, :gateway_response => e.message)
      end


    end
  end

  def send_sms(message, numbers)

    @savon_client.request :ns1, :one_to_many do

      soap.body = {
          "ns1:userName" => "01811393240",
          "ns1:userPassword" => "bce337",
          "ns1:messageText" => message,
          "ns1:numberList" => numbers,
          "ns1:smsType" => "TEXT",
          "ns1:maskName" => "DemoMask",
          "ns1:campaignName" => ""
      }
      soap.env_namespace = "SOAP-ENV"

    end
  end
end