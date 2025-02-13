module Debugger
  class QuitCommand < Command # :nodoc:
    self.control = true

    def regexp
      /^\s*(?:q(?:uit)?|exit)\s*$/
    end

    def execute
      begin
        if ENV['DEBUGGER_KEEP_PROCESS_ALIVE'] == "true"
          @delegate_sd_obj.interface.closing = true
          Debugger.breakpoints.clear
          @delegate_sd_obj.interface.command_queue << 'c'
        else
          @printer.print_msg("finished")
          @printer.print_debug("Exiting debugger.")
        end
      ensure
        exit! unless ENV['DEBUGGER_KEEP_PROCESS_ALIVE'] == "true" # exit -> exit!: No graceful way to stop threads...
      end
    end

    class << self
      def help_command
        %w[quit exit]
      end

      def help(cmd)
        %{
          q[uit]\texit from debugger, 
          exit\talias to quit
        }
      end
    end
  end
  
  class RestartCommand < Command # :nodoc:
    self.control = true

    def regexp
      / ^\s*
      (restart|R)
      (\s+ \S+ .*)?
      $
      /x
    end
    
    def execute
      if not defined? Debugger::RDEBUG_SCRIPT or not defined? Debugger::ARGV
        print "We are not in a context we can restart from.\n"
        return
      end
      if @match[2]
        args = Debugger::PROG_SCRIPT + " " + @match[2]
      else
        args = Debugger::ARGV.join(" ")
      end

      # An execv would be preferable to the "exec" below.
      cmd = Debugger::RDEBUG_SCRIPT + " " + args
      print "Re exec'ing:\n\t#{cmd}\n"
      exec cmd
    end

    class << self
      def help_command
        'restart'
      end

      def help(cmd)
        %{
          restart|R [args] 
          Restart the program. This is is a re-exec - all debugger state
          is lost. If command arguments are passed those are used.
        }
      end
    end
  end

  class StartCommand < Command # :nodoc:
    self.control = true

    def regexp
      /^\s*(start)(\s+ \S+ .*)?$/x
    end
    
    def execute
      @printer.print_debug("Starting: running program script")
      Debugger.run_prog_script #Debugger.prog_script_running?
    end

    class << self
      def help_command
        'start'
      end

      def help(cmd)
        %{
          run prog script
        }
      end
    end
  end


  class InterruptCommand < Command # :nodoc:
    self.event = false
    self.control = true
    self.need_context = true
    
    def regexp
      /^\s*i(?:nterrupt)?\s*$/
    end
    
    def execute
      unless Debugger.interrupt_last
        context = Debugger.thread_context(Thread.main)
        context.interrupt
      end
    end
    
    class << self
      def help_command
        'interrupt'
      end
      
      def help(cmd)
        %{
          i[nterrupt]\tinterrupt the program
        }
      end
    end
  end


  class DetachCommand < Command # :nodoc:
    self.control = true

    def regexp
      /^\s*detach\s*$/
    end

    def execute
      Debugger.stop
      Debugger.interface.close
      Debugger::MultiProcess.undo_monkey
      Debugger.control_thread = nil
      Thread.current.exit #@control_thread is a current thread
    end

    class << self
      def help_command
        'detach'
      end

      def help(cmd)
        %{
          detach\ndetach debugger\nnote: this option is only for remote debugging (or local attach)
        }
      end
    end
  end
end
