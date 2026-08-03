class LabImportsController < ApplicationController
  PER_PAGE = 15

  def index
    # Eager-load the attachment so listing filenames doesn't trigger a query per row.
    scope = LabImport.with_attached_file.order(created_at: :desc)
    @total_pages = [ (scope.count / PER_PAGE.to_f).ceil, 1 ].max
    @page = params[:page].to_i.clamp(1, @total_pages)
    @lab_imports = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
  end

  def new
    @lab_import = LabImport.new
  end

  def create
    file = params.dig(:lab_import, :file)
    if file.blank?
      @lab_import = LabImport.new
      flash.now[:alert] = "Please choose a file to upload."
      return render :new, status: :unprocessable_entity
    end

    @lab_import = LabImport.new
    @lab_import.file.attach(file)
    @lab_import.save!

    # Parsing/importing happens off the request cycle so the upload returns immediately.
    LabResultImportJob.perform_later(@lab_import.id)

    redirect_to lab_import_path(@lab_import)
  end

  def show
    @lab_import = LabImport.find(params[:id])
  end
end
