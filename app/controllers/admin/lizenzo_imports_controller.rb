class Admin::LizenzoImportsController < Admin::BaseController
  
  #Sorry for not using resource_controller railsdog - I wanted to, but then... I did it this way.
  #Verbosity is nice?
  #Feel free to refactor and submit a pull request.
  
  def index
    redirect_to :action => :new
  end
  
  def new
    @lizenzo_import = LizenzoImport.new
  end
  
  def create
    @lizenzo_import = LizenzoImport.create(params[:lizenzo_import])
    Delayed::Job.enqueue LizenzoImporter::ImportJob.new(@lizenzo_import, @current_user)
    flash[:notice] = t('lizenzo_import_processing')
    render :new
  end
  
end
