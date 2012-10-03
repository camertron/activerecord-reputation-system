##
#  Copyright 2012 Twitter, Inc
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
##

module ReputationSystem
  class Evaluation < ActiveRecord::Base
    self.table_name = 'rs_evaluations'
    belongs_to :source, :polymorphic => true
    belongs_to :target, :polymorphic => true
    has_one :sent_messages, :as => :sender, :class_name => 'ReputationSystem::ReputationMessage', :dependent => :destroy

    attr_accessible :reputation_name, :value, :source, :source_id, :source_type, :target, :target_id, :target_type

    # Sets an appropriate source type in case of Single Table Inheritance.
    before_validation :set_source_type_for_sti

    # the same source cannot evaluate the same target more than once.
    validates_uniqueness_of :source_id, :scope => [:reputation_name, :source_type, :target_id, :target_type]
    validate :source_must_be_defined_for_reputation_in_network

    def self.find_by_reputation_name_and_source_and_target(reputation_name, source, target)
      source_type = get_source_type_for_sti(source, target.class.name, reputation_name)
      ReputationSystem::Evaluation.find(:first,
                        :conditions => {:reputation_name => reputation_name.to_s,
                                        :source_id => source.id,
                                        :source_type => source_type,
                                        :target_id => target.id,
                                        :target_type => target.class.name
                                        })
    end

    def self.create_evaluation(reputation_name, value, source, target)
      ReputationSystem::Evaluation.create!(:reputation_name => reputation_name.to_s, :value => value,
                           :source_id => source.id, :source_type => source.class.name,
                           :target_id => target.id, :target_type => target.class.name)
    end

    protected

      def self.get_source_type_for_sti(source, target_type, reputation_name)
        valid_source_type = ReputationSystem::Network.get_reputation_def(target_type, reputation_name)[:source].to_s.camelize
        temp = source.class
        while temp && valid_source_type != temp.name && temp.name != "ActiveRecord::Base"
          temp = temp.superclass
        end
        temp ? temp.name : nil
      end

      def set_source_type_for_sti
        temp = self.class.get_source_type_for_sti(source, target_type, reputation_name)
        self.source_type = temp if temp
      end

      def source_must_be_defined_for_reputation_in_network
        unless source_type == ReputationSystem::Network.get_reputation_def(target_type, reputation_name)[:source].to_s.camelize
          errors.add(:source_type, "#{source_type} is not source of #{reputation_name} reputation")
        end
      end
  end
end