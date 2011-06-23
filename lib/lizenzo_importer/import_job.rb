module LizenzoImporter
  class ImportJob
    attr_accessor :lizenzo_import_id
    attr_accessor :user_id
    
    def initialize(lizenzo_import_record, user)
      self.lizenzo_import_id = lizenzo_import_record.id
      self.user_id = user.id
    end
    
    def perform
      begin
        lizenzo_import = LizenzoImport.find(self.lizenzo_import_id)
        results = lizenzo_import.import_data!
        UserMailer.lizenzo_import_results(User.find(self.user_id)).deliver
      rescue Exception => exp
        UserMailer.lizenzo_import_results(User.find(self.user_id), exp).deliver
      ensure
        # clear log!
        FileUtils.rm_f(LIZENZO_IMPORTER_SETTINGS[:log_to])
      end
    end
  end
end
