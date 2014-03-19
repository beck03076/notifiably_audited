module Audited
  # Specify this act if you want changes to your model to be saved in an
  # audit table.  This assumes there is an audits table ready.
  #
  #   class User < ActiveRecord::Base
  #     audited
  #   end
  #
  # To store an audit comment set model.audit_comment to your comment before
  # a create, update or destroy operation.
  #
  # See <tt>Audited::Adapters::ActiveRecord::Auditor::ClassMethods#audited</tt>
  # for configuration options
  module Auditor #:nodoc:
    extend ActiveSupport::Concern

    CALLBACKS = [:audit_create, :audit_update, :audit_destroy]

    module ClassMethods
      # == Configuration options
      #
      #
      # * +only+ - Only audit the given attributes
      # * +except+ - Excludes fields from being saved in the audit log.
      #   By default, Audited will audit all but these fields:
      #
      #     [self.primary_key, inheritance_column, 'lock_version', 'created_at', 'updated_at']
      #   You can add to those by passing one or an array of fields to skip.
      #
      #     class User < ActiveRecord::Base
      #       audited :except => :password
      #     end
      # * +protect+ - If your model uses +attr_protected+, set this to false to prevent Rails from
      #   raising an error.  If you declare +attr_accessible+ before calling +audited+, it
      #   will automatically default to false.  You only need to explicitly set this if you are
      #   calling +attr_accessible+ after.
      #
      # * +require_comment+ - Ensures that audit_comment is supplied before
      #   any create, update or destroy operation.
      #
      #     class User < ActiveRecord::Base
      #       audited :protect => false
      #       attr_accessible :name
      #     end
      #
      def notifiably_audited(options = {})
        # don't allow multiple calls
        return if self.included_modules.include?(Audited::Auditor::AuditedInstanceMethods)

        class_attribute :non_audited_columns,   :instance_writer => false
        class_attribute :auditing_enabled,      :instance_writer => false
        class_attribute :audit_associated_with, :instance_writer => false
        
        #====== beck added for notifiable ====
        class_attribute :audit_alert_to, :instance_writer => false
        class_attribute :audit_alert_for, :instance_writer => false
        class_attribute :audit_title, :instance_writer => false
        class_attribute :audit_create_comment, :instance_writer => false
        class_attribute :audit_update_comment, :instance_writer => false
        #=====================================

        if options[:only]
          except = self.column_names - options[:only].flatten.map(&:to_s)
        else
          except = default_ignored_attributes + Audited.ignored_attributes
          except |= Array(options[:except]).collect(&:to_s) if options[:except]
        end
        self.non_audited_columns = except
        self.audit_associated_with = options[:associated_with]
        
        #====== beck added for notifiable ====
        self.audit_alert_to = options[:alert_to] || :assigned_to
        self.audit_alert_for = options[:alert_for] || nil
        self.audit_title = options[:title] || :name
        self.audit_create_comment = options[:create_comment] || "New <<here>> has been created"
        self.audit_update_comment = options[:update_comment] || "Values of <<here>> has been updated"
        #=====================================

        if options[:comment_required]
          validates_presence_of :audit_comment, :if => :auditing_enabled
          before_destroy :require_comment
        end

        attr_accessor :audit_comment
        unless options[:allow_mass_assignment]
          attr_accessible :audit_comment
        end

        has_many :audits, :as => :auditable, :class_name => Audited.audit_class.name
        Audited.audit_class.audited_class_names << self.to_s

        after_create  :audit_create if !options[:on] || (options[:on] && options[:on].include?(:create))
        before_update :audit_update if !options[:on] || (options[:on] && options[:on].include?(:update))
        before_destroy :audit_destroy if !options[:on] || (options[:on] && options[:on].include?(:destroy))

        # Define and set an after_audit callback. This might be useful if you want
        # to notify a party after the audit has been created.
        define_callbacks :audit
        set_callback :audit, :after, :after_audit, :if => lambda { self.respond_to?(:after_audit) }

        attr_accessor :version

        extend Audited::Auditor::AuditedClassMethods
        include Audited::Auditor::AuditedInstanceMethods

        self.auditing_enabled = true
        
      end

      def has_associated_audits
        has_many :associated_audits, :as => :associated, :class_name => Audited.audit_class.name
      end
    end
    
#========  Audit Instance Methods - Means the methods on the target object =====================

    #====== beck modified for notifiable ====
    # @non_monitor is 1 initially, if somewhere an audit is created this is set to 0, so no future 
    # audit will be created.
    
    # if polymorphic, then 
    # [:polymorphic,"title",
    #  col of self to be displayed as comment,[:commentable_type,:commentable_id]]
    #----------------------------------------------
    # opts format for notifiably_audited method/gem
    #----------------------------------------------
    #   notifiably_audited alert_for: [[[:assigned_to],
    #                                   "Re-assigned",
    #                                   "This product has been reassigned",
    #                                   [:user,:email]],
    #                                   [[:color,:score],
    #                                    "Color/Score Changed",
    #                                   "Color/Score value is changed"],
    #                                   [[:product_status_id],
    #                                    "Status Changed",
    #                                   "Status of this product is changed",
    #                                    [:product_status,:name]]],
    #                     associated_with: :product_status, 
    #                      title: :name, 
    #                      create_comment: "New <<here>> has been created", 
    #                      update_comment: "Custom: Values of <<here>> has been updated"
    #
    #  &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
    #
    #   notifiably_audited alert_for: [[:polymorphic,
    #                                   nil,
    #                                   :content,
    #                                   [:commentable_type,:commentable_id]]]
    #
    # -----------
    # alert_to :
    # -----------
    # The column of the target_object that has the user_id to send 
    # the notification to.(receiver_id of the Audit record) 
    # -----------
    # alert_for :
    # -----------
    # Takes array of arrays as an argument. Every array in the main array corresponds to
    # one or group of columns update and how to notify.
    # Following is the index wise explanation of the arrays.
    # 1. Column name or Column names
    # 2. Title of the notification(title column of the Audit record)
    # 3. Description of the notification(audit_comment column of the Audit record)
    # 4. If the column name is a foreign key of an belongs_to association, then the model_name of the
    #    associated model and the column of the model to be displayed in title is specified
    # -----------
    # title :
    # -----------
    # Takes 1 column name or a method name of the target object as an argument, in order to prompt the 
    # title of the target object wherever needed in the notification
    # ---------------
    # create_comment :
    # ---------------
    # Default audit_comment for create action
    # ---------------
    # update_comment :
    # ---------------
    # Default audit_comment for update action
    #
    # ***************
    # :polymorphic
    # ***************
    # If this is passed as the first argument of the alert_for option, then it means, the current_model 
    # is polymorphic and the target_object is a different model to which the current model is
    # polymorphic to.
    # 
    # In the above case the 4th argument of the alert_for option should be the type and id of the
    # polymorphic model.(Ex: [:commentable_type,commentable_id])
    #----------------------------------------------
    #=====================================

    module AuditedInstanceMethods
      # Temporarily turns off auditing while saving.
      def save_without_auditing
        without_auditing { save }
      end

      # Executes the block with the auditing callbacks disabled.
      #
      #   @foo.without_auditing do
      #     @foo.save
      #   end
      #
      def without_auditing(&block)
        self.class.without_auditing(&block)
      end

      # Gets an array of the revisions available
      #
      #   user.revisions.each do |revision|
      #     user.name
      #     user.version
      #   end
      #
      def revisions(from_version = 1)
        audits = self.audits.from_version(from_version)
        return [] if audits.empty?
        revisions = []
        audits.each do |audit|
          revisions << audit.revision
        end
        revisions
      end

      # Get a specific revision specified by the version number, or +:previous+
      def revision(version)
        revision_with Audited.audit_class.reconstruct_attributes(audits_to(version))
      end

      # Find the oldest revision recorded prior to the date/time provided.
      def revision_at(date_or_time)
        audits = self.audits.up_until(date_or_time)
        revision_with Audited.audit_class.reconstruct_attributes(audits) unless audits.empty?
      end

      # List of attributes that are audited.
      def audited_attributes
        attributes.except(*non_audited_columns)
      end

      protected

      def revision_with(attributes)
        self.dup.tap do |revision|
          revision.id = id
          revision.send :instance_variable_set, '@attributes', self.attributes
          revision.send :instance_variable_set, '@new_record', self.destroyed?
          revision.send :instance_variable_set, '@persisted', !self.destroyed?
          revision.send :instance_variable_set, '@readonly', false
          revision.send :instance_variable_set, '@destroyed', false
          revision.send :instance_variable_set, '@_destroyed', false
          revision.send :instance_variable_set, '@marked_for_destruction', false
          Audited.audit_class.assign_revision_attributes(revision, attributes)

          # Remove any association proxies so that they will be recreated
          # and reference the correct object for this revision. The only way
          # to determine if an instance variable is a proxy object is to
          # see if it responds to certain methods, as it forwards almost
          # everything to its target.
          for ivar in revision.instance_variables
            proxy = revision.instance_variable_get ivar
            if !proxy.nil? and proxy.respond_to? :proxy_respond_to?
              revision.instance_variable_set ivar, nil
            end
          end
        end
      end

      private

      def audited_changes
        changed_attributes.except(*non_audited_columns).inject({}) do |changes,(attr, old_value)|
          changes[attr] = [old_value, self[attr]]
          changes
        end
      end

      def audits_to(version = nil)
        if version == :previous
          version = if self.version
                      self.version - 1
                    else
                      previous = audits.descending.offset(1).first
                      previous ? previous.version : 1
                    end
        end
        audits.to_version(version)
      end
      #====== beck modified for notifiable ====
      
      def audit_create
        set_audit_values("create")# also sets @non_monitor as 1
        if !audit_alert_for.nil?
           audit_alert_for.each do |f|
              if f[0] == :polymorphic
                polymorphic_audit(f)# also sets @non_monitor as 0
              end
           end
         end
         
         if @non_monitor == 1 
           write_audit(@audit_values)
         end
      end
      
      def audit_update
        unless (changes = audited_changes).empty? && audit_comment.blank?
          set_audit_values("update")# also sets @non_monitor as 1
          
          if !audit_alert_for.nil?
              audit_alert_for.each do |f|
                  if f[0] == :polymorphic
                    polymorphic_audit(f)# also sets @non_monitor as 0
                  else
                    changed_eq_opts(f)# also sets @non_monitor as 0
                  end
              end
          end
          
          if @non_monitor == 1 
            write_audit(@audit_values)
          end
          
        end
      end
      
      def audit_destroy
        write_audit(:action => 'destroy', :audited_changes => audited_attributes,
                    :comment => audit_comment, :receiver_id => self.send(audit_alert_to), :checked => false)
      end
      #=== Following methods helps audit_create and update ======
      # set_audit_values
      # polymorphic_audit
      # changed_eq_opts
      #==========================================================
      
      def set_audit_values(type)
        @non_monitor = 1
        # based on type the audit attributes are set
        if (type == "create")
          v_audited_changes = audited_attributes
        elsif (type == "update")
          v_audited_changes = changes
        end
        # the <<here>> part of the comment is replaced with class name
        v_comment = send("audit_" + type +"_comment").gsub(/<<here>>/,self.class.name)
        # fields of the audit record set initially as hash, can be over ridden
        @audit_values = {action: type, 
                         audited_changes: v_audited_changes,
                         comment: v_comment, 
                         title: (self.send(audit_title) rescue self.class.name),
                         checked: false,
                         receiver_id: (self.send(audit_alert_to) rescue nil)}
      end
      
      def polymorphic_audit(opts)
        # polymorphic - so the actual object is set, not the polymorphed object(product not comment)
        target_object = self.send(opts[3][0]).constantize.find(self.send(opts[3][1]))
        # overriding the audit values based on polymorphic opts
        @audit_values[:title] = (opts[1] || @audit_values[:title]).to_s + " - #{target_object.class.name}[#{target_object.send(audit_title)}]"
        @audit_values[:comment] = self.send(opts[2])[0..20].to_s + "..."
        @audit_values[:receiver_id] = target_object.send(audit_alert_to)
        # actual recording of audit
        write_audit(@audit_values)
        # setting to 0, so dont record anymore audits
        @non_monitor = 0
      end
      
      def changed_eq_opts(opts)        
        # the cols that are going to be modified as identified by audited gem
        changed = changes.keys.map &:to_sym
        # the cols to be listened to, as passed in the opts
        opts_changes = opts[0]
        # if the sub array(to be listened) is included in the main array(audited identified cols)
        if ((opts_changes - changed).size == 0)
          # overriding audit values
          @audit_values[:title] = opts[1]
          @audit_values[:comment] = opts[2] 
            # if 3rd argument is present in the opts, then overriding title
            if opts[3].present?
              append = opts[3][0].to_s.camelize.constantize.find(self.send(opts[0][0])).send(opts[3][1])
              @audit_values[:title] = @audit_values[:title] + "[#{append}]"
            end
          # actual recording of audit
          write_audit(@audit_values)
          # setting to 0, so dont record anymore audits
          @non_monitor = 0
        end
      end
      #========================================

      def write_audit(attrs)
        attrs[:associated] = self.send(audit_associated_with) unless audit_associated_with.nil?
        self.audit_comment = nil
        run_callbacks(:audit)  { self.audits.create(attrs) } if auditing_enabled
      end

      def require_comment
        if auditing_enabled && audit_comment.blank?
          errors.add(:audit_comment, "Comment required before destruction")
          return false
        end
      end

      CALLBACKS.each do |attr_name|
        alias_method "#{attr_name}_callback".to_sym, attr_name
      end

      def empty_callback #:nodoc:
      end

    end # InstanceMethods

    module AuditedClassMethods
      # Returns an array of columns that are audited. See non_audited_columns
      def audited_columns
        self.columns.select { |c| !non_audited_columns.include?(c.name) }
      end

      # Executes the block with auditing disabled.
      #
      #   Foo.without_auditing do
      #     @foo.save
      #   end
      #
      def without_auditing(&block)
        auditing_was_enabled = auditing_enabled
        disable_auditing
        block.call.tap { enable_auditing if auditing_was_enabled }
      end

      def disable_auditing
        self.auditing_enabled = false
      end

      def enable_auditing
        self.auditing_enabled = true
      end

      # All audit operations during the block are recorded as being
      # made by +user+. This is not model specific, the method is a
      # convenience wrapper around
      # @see Audit#as_user.
      def audit_as( user, &block )
        Audited.audit_class.as_user( user, &block )
      end
    end
  end
end
