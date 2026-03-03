namespace :sync do
  desc "Run two-way sync with external Todo API"
  task todos: :environment do
    result = TodoSyncService.new.call

    puts "Sync complete. Success: #{result[:success].count}, Failed: #{result[:failed].count}"

    result[:success].each do |entry|
      puts "  OK   list #{entry[:id]}: #{entry[:action]}"
    end

    result[:failed].each do |entry|
      puts "  FAIL list #{entry[:id]}: #{entry[:error]}"
    end
  end
end
