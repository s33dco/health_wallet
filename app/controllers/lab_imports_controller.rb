class LabImportsController < ApplicationController
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
