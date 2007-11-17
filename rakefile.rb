task :default do
  Rake::Task['run_specs'].invoke
end

task :run_specs do
  puts `spec --require specs/bootstrap.rb --color --format specdoc specs/*_spec.rb`
end