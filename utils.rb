
def ensure_folder_exists(folder_path)
    unless File.exist?(folder_path)
        # Make any parent folders first
        if ensure_folder_exists(File.dirname(folder_path))
            puts "Creating directory #{folder_path}"
            Dir.mkdir(folder_path)
        end
    end
    File.exist?(folder_path) && File.directory?(folder_path)
end

