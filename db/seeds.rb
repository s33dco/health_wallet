# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Clearing existing data..."
Assessment.destroy_all
Patient.destroy_all

puts "Creating patients..."

patients_data = [
  { name: "Alice Johnson", dob: Date.new(1985, 3, 15), sex_at_birth: "Female" },
  { name: "Bob Smith", dob: Date.new(1990, 7, 22), sex_at_birth: "Male" },
  { name: "Carol Williams", dob: Date.new(1978, 11, 8), sex_at_birth: "Female" },
  { name: "David Brown", dob: Date.new(1995, 1, 30), sex_at_birth: "Male" },
  { name: "Eva Martinez", dob: Date.new(1982, 5, 12), sex_at_birth: "Female" },
  { name: "Frank Davis", dob: Date.new(1970, 9, 3), sex_at_birth: "Male" },
  { name: "Grace Lee", dob: Date.new(1988, 12, 25), sex_at_birth: "Female" },
  { name: "Henry Wilson", dob: Date.new(1992, 4, 17), sex_at_birth: "Male" },
  { name: "Irene Taylor", dob: Date.new(1975, 8, 9), sex_at_birth: "Female" },
  { name: "Jack Anderson", dob: Date.new(1998, 2, 28), sex_at_birth: "Male" },
  { name: "Karen Thomas", dob: Date.new(1983, 6, 14), sex_at_birth: "Female" },
  { name: "Leo Garcia", dob: Date.new(1991, 10, 21), sex_at_birth: "Male" },
  { name: "Maria Rodriguez", dob: Date.new(1986, 3, 7), sex_at_birth: "Female" },
  { name: "Nathan Clark", dob: Date.new(1979, 7, 19), sex_at_birth: "Male" },
  { name: "Olivia Lewis", dob: Date.new(1994, 11, 2), sex_at_birth: "Female" },
  { name: "Peter Hall", dob: Date.new(1972, 1, 11), sex_at_birth: "Male" },
  { name: "Quinn Young", dob: Date.new(1989, 5, 26), sex_at_birth: "Female" },
  { name: "Robert King", dob: Date.new(1996, 9, 13), sex_at_birth: "Male" },
  { name: "Sarah Wright", dob: Date.new(1981, 12, 4), sex_at_birth: "Female" },
  { name: "Thomas Scott", dob: Date.new(1993, 4, 8), sex_at_birth: "Male" },
  { name: "Uma Patel", dob: Date.new(1987, 8, 31), sex_at_birth: "Female" },
  { name: "Victor Chen", dob: Date.new(1974, 2, 16), sex_at_birth: "Male" },
  { name: "Wendy Adams", dob: Date.new(1999, 6, 23), sex_at_birth: "Female" },
  { name: "Xavier Nelson", dob: Date.new(1980, 10, 5), sex_at_birth: "Male" },
  { name: "Yolanda Hill", dob: Date.new(1997, 3, 29), sex_at_birth: "Female" }
]

observation_types = [
  { name: "Blood Pressure (Systolic)", code: "8480-6", units: "mmHg", range: 90..180 },
  { name: "Blood Pressure (Diastolic)", code: "8462-4", units: "mmHg", range: 60..120 },
  { name: "Heart Rate", code: "8867-4", units: "bpm", range: 50..120 },
  { name: "Body Temperature", code: "8310-5", units: "°C", range: 36.0..39.0 },
  { name: "Respiratory Rate", code: "9279-1", units: "breaths/min", range: 12..25 },
  { name: "Oxygen Saturation", code: "2708-6", units: "%", range: 92..100 },
  { name: "Body Weight", code: "29463-7", units: "kg", range: 45..120 },
  { name: "Body Height", code: "8302-2", units: "cm", range: 150..200 },
  { name: "Blood Glucose", code: "2339-0", units: "mg/dL", range: 70..200 },
  { name: "Cholesterol", code: "2093-3", units: "mg/dL", range: 120..280 }
]

patients_data.each do |patient_attrs|
  patient = Patient.create!(patient_attrs)

  # Create random number of assessments (0-5) for each patient
  rand(0..5).times do |i|
    assessment = patient.assessments.create!(
      date: (Date.today - rand(1..365)).to_s,
      reference: "ASM-#{patient.id.to_s[-4..]}-#{i + 1}"
    )

    # Add random observations (2-6) to each assessment
    observation_types.sample(rand(2..6)).each do |obs_type|
      value = if obs_type[:range].first.is_a?(Float)
                rand(obs_type[:range]).round(1)
      else
                rand(obs_type[:range]).to_f
      end

      assessment.observations.create!(
        name: obs_type[:name],
        code: obs_type[:code],
        value: value,
        units: obs_type[:units]
      )
    end
  end
end

puts "Created #{Patient.count} patients with #{Assessment.count} assessments and #{Assessment.all.sum { |a| a.observations.count }} observations."

# --- Observation code reference data (LOINC) ---------------------------------------
# The importer only creates observations whose code appears in this controlled list.
# Seeded idempotently so it is safe to re-run without clobbering existing records.
puts "Seeding observation codes..."

OBSERVATION_CODES = {
  "8480-6"  => "Blood Pressure (Systolic)",
  "8462-4"  => "Blood Pressure (Diastolic)",
  "8867-4"  => "Heart Rate",
  "8310-5"  => "Body Temperature",
  "9279-1"  => "Respiratory Rate",
  "2708-6"  => "Oxygen Saturation",
  "29463-7" => "Body Weight",
  "8302-2"  => "Body Height",
  "2339-0"  => "Blood Glucose",
  "2093-3"  => "Cholesterol"
}.freeze

OBSERVATION_CODES.each do |code, description|
  ObservationCode.find_or_create_by!(code: code) do |oc|
    oc.description = description
  end
end

puts "Seeded #{ObservationCode.count} observation codes."
