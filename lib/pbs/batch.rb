require 'open3'

module PBS
  # Object used for simplified communication with a batch server
  class Batch
    # The host of the Torque batch server
    # @example OSC's Oakley batch server
    #   my_conn.host #=> "oak-batch.osc.edu"
    # @return [String] the batch server host
    attr_reader :host

    # The path to the Torque client installation libraries
    # @example For Torque 5.0.0
    #   my_conn.lib.to_s #=> "/usr/local/torque/5.0.0/lib"
    # @return [Pathname] path to torque libraries
    attr_reader :lib

    # The path to the Torque client installation binaries
    # @example For Torque 5.0.0
    #   my_conn.bin.to_s #=> "/usr/local/torque/5.0.0/bin"
    # @return [Pathname] path to torque binaries
    attr_reader :bin

    # @param host [#to_s] the batch server host
    # @param lib [#to_s] path to torque installation libraries
    # @param bin [#to_s] path to torque installation binaries
    def initialize(host:, lib: "", bin: "", **_)
      @host    = host.to_s
      @lib     = Pathname.new(lib.to_s)
      @bin     = Pathname.new(bin.to_s)
    end

    # Convert object to hash
    # @return [Hash] the hash describing this object
    def to_h
      {host: host, lib: lib, bin: bin}
    end

    # The comparison operator
    # @param other [#to_h] batch server to compare against
    # @return [Boolean] how batch servers compare
    def ==(other)
      to_h == other.to_h
    end

    # Checks whether two batch server objects are completely identical to each
    # other
    # @param other [Batch] batch server to compare against
    # @return [Boolean] whether same objects
    def eql?(other)
      self.class == other.class && self == other
    end

    # Generates a hash value for this object
    # @return [Fixnum] hash value of object
    def hash
      [self.class, to_h].hash
    end

    # Creates a connection to batch server and calls block in context of this
    # connection
    # @yieldparam cid [Fixnum] connection id from established batch server connection
    # @yieldreturn the final value of the block
    def connect(&block)
      Torque.lib = lib.join('libtorque.so')
      cid = Torque.pbs_connect(host)
      Torque.raise_error(cid.abs) if cid < 0  # raise error if negative connection id
      begin
        value = yield cid
      ensure
        Torque.pbs_disconnect(cid)            # always close connection
      end
      Torque.check_for_error                  # check for errors at end
      value
    end

    # Get a hash with status info for this batch server
    # @example Status info for OSC Oakley batch server
    #   my_conn.get_status
    #   #=>
    #   #{
    #   #  "oak-batch.osc.edu:15001" => {
    #   #    :server_state => "Idle",
    #   #    ...
    #   #  }
    #   #}
    # @param filters [Array<Symbol>] list of attribs to filter on
    # @return [Hash] status info for batch server
    def get_status(filters: [])
      connect do |cid|
        filters = PBS::Torque::Attrl.from_list filters
        batch_status = Torque.pbs_statserver cid, filters, nil
        batch_status.to_h.tap { Torque.pbs_statfree batch_status }
      end
    end

    # Get a list of hashes of the queues on the batch server
    # @example Status info for OSC Oakley queues
    #   my_conn.get_queues
    #   #=>
    #   #{
    #   #  "parallel" => {
    #   #    :queue_type => "Execution",
    #   #    ...
    #   #  },
    #   #  "serial" => {
    #   #    :queue_type => "Execution",
    #   #    ...
    #   #  },
    #   #  ...
    #   #}
    # @param id [#to_s] the id of requested information
    # @param filters [Array<Symbol>] list of attribs to filter on
    # @return [Hash] hash of details for the queues
    def get_queues(id: '', filters: [])
      connect do |cid|
        filters = PBS::Torque::Attrl.from_list(filters)
        batch_status = Torque.pbs_statque cid, id.to_s, filters, nil
        batch_status.to_h.tap { Torque.pbs_statfree batch_status }
      end
    end

    # Get info for given batch server's queue
    # @example Status info for OSC Oakley's parallel queue
    #   my_conn.get_queue("parallel")
    #   #=>
    #   #{
    #   #  "parallel" => {
    #   #    :queue_type => "Execution",
    #   #    ...
    #   #  }
    #   #}
    # @param (see @get_queues)
    # @return [Hash] status info for the queue
    def get_queue(id, **kwargs)
      get_queues(id: id, **kwargs)
    end


    # Get a list of hashes of the nodes on the batch server
    # @example Status info for OSC Oakley nodes
    #   my_conn.get_nodes
    #   #=>
    #   #{
    #   #  "n0001" => {
    #   #    :np => "12",
    #   #    ...
    #   #  },
    #   #  "n0002" => {
    #   #    :np => "12",
    #   #    ...
    #   #  },
    #   #  ...
    #   #}
    # @param id [#to_s] the id of requested information
    # @param filters [Array<Symbol>] list of attribs to filter on
    # @return [Hash] hash of details for nodes
    def get_nodes(id: '', filters: [])
      connect do |cid|
        filters = PBS::Torque::Attrl.from_list(filters)
        batch_status = Torque.pbs_statnode cid, id.to_s, filters, nil
        batch_status.to_h.tap { Torque.pbs_statfree batch_status }
      end
    end

    # Get info for given batch server's node
    # @example Status info for OSC Oakley's 'n0001' node
    #   my_conn.get_node('n0001')
    #   #=>
    #   #{
    #   #  "n0001" => {
    #   #    :np => "12",
    #   #    ...
    #   #  }
    #   #}
    # @param (see #get_nodes)
    # @return [Hash] status info for the node
    def get_node(id, **kwargs)
      get_nodes(id: id, **kwargs)
    end

    # Get a list of hashes of the jobs on the batch server
    # @example Status info for OSC Oakley jobs
    #   my_conn.get_jobs
    #   #=>
    #   #{
    #   #  "10219837.oak-batch.osc.edu" => {
    #   #    :Job_Owner => "bob@oakley02.osc.edu",
    #   #    :Job_Name => "CFD_Solver",
    #   #    ...
    #   #  },
    #   #  "10219838.oak-batch.osc.edu" => {
    #   #    :Job_Owner => "sally@oakley01.osc.edu",
    #   #    :Job_Name => "FEA_Solver",
    #   #    ...
    #   #  },
    #   #  ...
    #   #}
    # @param id [#to_s] the id of requested information
    # @param filters [Array<Symbol>] list of attribs to filter on
    # @return [Hash] hash of details for jobs
    def get_jobs(id: '', filters: [])
      connect do |cid|
        filters = PBS::Torque::Attrl.from_list(filters)
        batch_status = Torque.pbs_statjob cid, id.to_s, filters, nil
        batch_status.to_h.tap { Torque.pbs_statfree batch_status }
      end
    end

    # Get info for given batch server's job
    # @example Status info for OSC Oakley's '10219837.oak-batch.osc.edu' job
    #   my_conn.get_job('102719837.oak-batch.osc.edu')
    #   #=>
    #   #{
    #   #  "10219837.oak-batch.osc.edu" => {
    #   #    :Job_Owner => "bob@oakley02.osc.edu",
    #   #    :Job_Name => "CFD_Solver",
    #   #    ...
    #   #  }
    #   #}
    # @param (see #get_jobs)
    # @return [Hash] hash with details of job
    def get_job(id, **kwargs)
      get_jobs(id: id, **kwargs)
    end

    # Put specified job on hold
    # Possible hold types:
    #   :u => Available to the owner of the job, the batch operator and the batch administrator
    #   :o => Available to the batch operator and the batch administrator
    #   :s => Available to the batch administrator
    # @example Put job '10219837.oak-batch.osc.edu' on hold
    #   my_conn.hold_job('10219837.oak-batch.osc.edu')
    # @param id [#to_s] the id of the job
    # @param type [#to_s] type of hold to be applied
    # @return [void]
    def hold_job(id, type: :u)
      connect do |cid|
        Torque.pbs_holdjob cid, id.to_s, type.to_s, nil
      end
    end

    # Release a specified job that is on hold
    # Possible hold types:
    #   :u => Available to the owner of the job, the batch operator and the batch administrator
    #   :o => Available to the batch operator and the batch administrator
    #   :s => Available to the batch administrator
    # @example Release job '10219837.oak-batch.osc.edu' from hold
    #   my_conn.release_job('10219837.oak-batch.osc.edu')
    # @param id [#to_s] the id of the job
    # @param type [#to_s] type of hold to be removed
    # @return [void]
    def release_job(id, type: :u)
      connect do |cid|
        Torque.pbs_rlsjob cid, id.to_s, type.to_s, nil
      end
    end

    # Delete a specified job from batch server
    # @example Delete job '10219837.oak-batch.osc.edu' from batch
    #   my_conn.delete_job('10219837.oak-batch.osc.edu')
    # @param id [#to_s] the id of the job
    # @return [void]
    def delete_job(id)
      connect do |cid|
        Torque.pbs_deljob cid, id.to_s, nil
      end
    end

    # Submit a script to the batch server
    # @example Submit a script with a few PBS directives
    #   my_conn.submit_script("/path/to/script",
    #     headers: {
    #       Job_Name: "myjob",
    #       Join_Path: "oe"
    #     },
    #     resources: {
    #       nodes: "4:ppn=12",
    #       walltime: "12:00:00"
    #     },
    #     envvars: {
    #       TOKEN: "asd90f9sd8g90hk34"
    #     }
    #   )
    #   #=> "6621251.oak-batch.osc.edu"
    # @param script [#to_s] path to the script
    # @param queue [#to_s] queue to submit script to
    # @param headers [Hash] pbs headers
    # @param resources [Hash] pbs resources
    # @param envvars [Hash] pbs environment variables
    # @param qsub [Boolean] whether use library or binary for submission
    # @return [String] the id of the job that was created
    def submit_script(script, queue: nil, headers: {}, resources: {}, envvars: {}, qsub: true)
      send(qsub ? :qsub_submit : :pbs_submit, script.to_s, queue.to_s, headers, resources, envvars)
    end

    # Submit a script expanded into a string to the batch server
    # @param string [#to_s] script as a string
    # @param (see #submit_script)
    # @return [String] the id of the job that was created
    def submit_string(string, **kwargs)
      Tempfile.open('qsub.') do |f|
        f.write string.to_s
        f.close
        submit_script(f.path, **kwargs)
      end
    end

    private
      # Submit a script using Torque library
      def pbs_submit(script, queue, headers, resources, envvars)
        attribs = headers.dup
        attribs[ATTR[:l]] = resources.dup unless resources.empty?
        attribs[ATTR[:v]] = envvars.map{|k,v| "#{k}=#{v}"}.join(",") unless envvars.empty?

        connect do |cid|
          attropl = Torque::Attropl.from_hash attribs
          Torque.pbs_submit cid, attropl, script, queue, nil
        end
      end

      # Mapping of Torque attribute to `qsub` arguments
      def qsub_arg(key, value)
        case key
        # common attributes
        when :Execution_Time
          ['-a', value.to_s]
        when :Checkpoint
          ['-c', value.to_s]
        when :Error_Path
          ['-e', value.to_s]
        when :fault_tolerant
          ['-f']
        when :Hold_Types
          ['-h']
        when :Join_Path
          ['-j', value.to_s]
        when :Keep_Files
          ['-k', value.to_s]
        when :Mail_Points
          ['-m', value.to_s]
        when :Output_Path
          ['-o', value.to_s]
        when :Priority
          ['-p', value.to_s]
        when :Rerunable
          ['-r', value.to_s]
        when :job_array_request
          ['-t', value.to_s]
        when :User_List
          ['-u', value.to_s]
        when :Account_Name
          ['-A', value.to_s]
        when :Mail_Users
          ['-M', value.to_s]
        when :Job_Name
          ['-N', value.to_s]
        when :Shell_Path_List
          ['-S', value.to_s]
        # uncommon attributes
        when :job_arguments
          ['-F', value.to_s]
        when :init_work_dir
          ['-d', value.to_s] # sets PBS_O_INITDIR
        when :reservation_id
          ['-W', "x=advres:#{value}"] # use resource manager extensions for Moab
        # everything else
        else
          ['-W', "#{key}=#{value}"]
        end
      end

      # Submit a script using Torque binary
      # NB: The binary includes many useful filters and is preferred
      def qsub_submit(script, queue, headers, resources, envvars)
        params  = []
        params += ["-q", "#{queue}"] unless queue.empty?
        params += headers.map {|k,v| qsub_arg(k,v)}.flatten
        params += resources.map{|k,v| ["-l", "#{k}=#{v}"]}.flatten
        params += ["-v", envvars.map{|k,v| "#{k}=#{v}"}.join(",")] unless envvars.empty?
        params << script

        env = {
          "PBS_DEFAULT"     => "#{host}",
          "LD_LIBRARY_PATH" => "#{lib}:#{ENV['LD_LIBRARY_PATH']}"
        }
        cmd = bin.join("qsub").to_s
        o, e, s = Open3.capture3(env, cmd, *params)
        raise PBS::Error, e unless s.success?
        o.chomp
      end
  end
end
