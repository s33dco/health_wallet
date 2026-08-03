class AssessmentsController < ApplicationController
  # Raised when a submitted observation value isn't a real number, so it can be reported to
  # the user instead of silently coercing to 0.0 or bubbling up as an unhandled error.
  InvalidObservationValue = Class.new(StandardError)

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
  rescue Mongoid::Errors::DocumentNotFound, InvalidObservationValue => e
    @patient = @assessment.patient
    flash.now[:alert] = e.is_a?(InvalidObservationValue) ? e.message : "That observation no longer exists."
    render :edit, status: :unprocessable_entity
  end

  private

  # Apply edited values through Observation#record_reading! rather than a blind nested
  # update, so a manual correction is preserved in the audit trail just like an import is
  # (tagged "manual_edit" to distinguish it from "hl7_import"). Unchanged rows are skipped
  # so re-saving the form doesn't inflate the history.
  def apply_observation_edits(assessment)
    observation_edits.each do |attrs|
      observation = assessment.observations.find(attrs[:id])
      value = parse_value(attrs[:value], observation)
      units = attrs[:units]
      next if observation.value == value && observation.units == units

      observation.record_reading!(value: value, units: units, source: "manual_edit")
    end
  end

  # `to_f` would silently coerce a blank/garbled value to 0.0; Float() raises on anything
  # that isn't a genuine number, so a bad submission is reported instead of quietly saved.
  def parse_value(raw, observation)
    Float(raw)
  rescue ArgumentError, TypeError
    raise InvalidObservationValue, "Invalid value #{raw.inspect} for #{observation.name}"
  end

  def observation_edits
    params.require(:assessment)
          .fetch(:observations_attributes, {})
          .values
          .map { |attrs| attrs.permit(:id, :value, :units) }
  end
end
