class AssessmentsController < ApplicationController
  def show
    @assessment = Assessment.find(params[:id])
    @patient = @assessment.patient
    @observations = @assessment.observations
  end

  def edit
    @assessment = Assessment.find(params[:id])
    @patient = @assessment.patient
  end

  def update
    @assessment = Assessment.find(params[:id])
    apply_observation_edits(@assessment)

    redirect_to assessment_path(@assessment), notice: "Assessment updated successfully."
  end

  private

  # Apply edited values through Observation#record_reading! rather than a blind nested
  # update, so a manual correction is preserved in the audit trail just like an import is
  # (tagged "manual_edit" to distinguish it from "hl7_import"). Unchanged rows are skipped
  # so re-saving the form doesn't inflate the history.
  def apply_observation_edits(assessment)
    observation_edits.each do |attrs|
      observation = assessment.observations.find(attrs[:id])
      value = attrs[:value].to_f
      units = attrs[:units]
      next if observation.value == value && observation.units == units

      observation.record_reading!(value: value, units: units, source: "manual_edit")
    end
  end

  def observation_edits
    params.require(:assessment)
          .fetch(:observations_attributes, {})
          .values
          .map { |attrs| attrs.permit(:id, :value, :units) }
  end
end
