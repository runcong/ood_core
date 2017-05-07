# Object used for simplified communication with a LSF batch server
#
# @api private
class OodCore::Job::Adapters::Lsf::Helper

  # convert string in format "03/31-14:46:42" to Time object
  # assumes time being parsed is a time that ocurred in the past
  # not to be used for parsing times in the future (like estimated FINISH_TIME)
  def parse_past_time(t, ignore_errors: false)
    return nil if t.nil? || t.empty? || t == "-"
    year = Time.now.year
    time = Time.parse("#{year}/#{t}")

    # handle edge case where job started before new year
    time = Time.parse("#{year - 1}/#{t}") if time.month > Time.now.month

    time

  rescue ArgumentError => e
    raise e unless ignore_errors

    #TODO: warn via logger

    nil
  end

  # convert exec_host string format from bjobs to a hash
  # i.e. "c012" => [{host: "c012", slots: 1}]
  # i.e. "4*c012:8*c013" => [{host: "c012", slots: 4}, {host: "c013", slots: 8}]
  def parse_exec_host(exec_host_str)
    return [] if exec_host_str.nil? || exec_host_str.empty?

    exec_host_str.scan(exec_host_regex).map do |match|
      {host: match[2], slots: match[1] ? match[1].to_i : 1}
    end
  end

  def exec_host_regex
    @exec_host_regex ||= Regexp.new(/((\d+)\*)?([^:]+)/)
  end

  # given current time, dispatch time, and finish time values, estimate the
  # runtime for a job; this estimate will be accurate if the job never enters a
  # suspended state during its execution
  def estimate_runtime(current_time:, start_time:, finish_time:)
    return nil if start_time.nil?

    (finish_time || current_time) - start_time
  end

  # Convert CPU_USED string to seconds
  #
  # example strings of cpu_used in LSF 8.3:
  #
  # 060:24:00.00
  # 046:19:37.00
  # 1118:59:09.00
  # 000:00:00.00
  # 000:48:18.39
  # 003:11:36.67
  # 003:24:40.95
  # 50769:48:00.-48
  # 50835:48:48.-48
  #
  # my guess is: hours:minutes:seconds.????
  #
  # @return [Fixnum, nil] cpu used as seconds
  def parse_cpu_used(cpu_used)
    if cpu_used =~ /^(\d+):(\d+):(\d+)\..*$/
      $1.to_i*3600 + $2.to_i*60 + $3.to_i
    end
  end
end
