#!/usr/bin/env ruby

require 'date'
require 'highline/import'
require 'aws-sdk-core'

creds = {
  access_key_id:"<AWS-ACCESS-KEY>",
  region:"<AWS-REGION>",
  secret_access_key:"<AWS-SECRET-ACCESS-KEY>"
}

S3 = Aws::S3::Client.new(creds)

class CreateZip

  def initialize
    @sponsors =  Dir.glob('*').select { |f| File.directory?(f) }
    @sponsors.unshift("")
    menu
  end

  def zip_sponsor
    puts "Select sponsor number to create zip or Type 'm' to return to the main menu"
    input = gets.chomp.to_i

    # if input is other than a number from the list it goes to menu
    menu if (input == 0 or input > @sponsors.length-1)

    puts "you answered with #{@sponsors[input.to_i]}"
    puts "Continue ? (y/n)"
    i = gets.chomp.downcase
    menu if i == "n"

    puts "\n\n\n"

    root = Dir.pwd

    # chosen_folder = Dir.glob("#{root}/#{@sponsors[input.to_i]}/*").select{ |f| File.directory? f }.last

    # Reads all the dated folders in the sponsors folder
    inner_folders = Dir.glob("#{root}/#{@sponsors[input.to_i]}/*").select{ |f| File.directory? f }

    # If there is only 1 folder make that as default chosen folder
    # Else list all the folders
    if inner_folders.length < 2
          chosen_folder = inner_folders[0]
    else
      puts "Choose the folder to use"
      inner_folders.each_with_index do |folder_name, idx|
        puts idx.to_s + " " + folder_name.reverse.split("/")[0].reverse
      end
        input = gets.chomp.to_i
        chosen_folder = inner_folders[input]
    end

    #Check if Deployable folder exists, if it doesnt exit out
    abort("WARNING DID NOT FIND THE DEPLOYABLE FOLDER IN >> #{@sponsors[input.to_i]} << \n........TERMINATING SCRIPT.........") unless Dir.entries("#{chosen_folder}").include?("Deployable")

    #Zip the Deployable folder inside the chosen folder
    to_zip = Dir.glob("#{chosen_folder}/Deployable/*").select{ |f| File.directory? f}
    p to_zip


    to_zip.each do |folder_to_zip|
      to_path = File.expand_path("..",folder_to_zip)

      Dir.chdir(to_path)

      sponsor_name = File.basename(folder_to_zip)

      final_filename = "#{Date.today.to_s}-#{sponsor_name}.zip"

      #Zips the folder
      system("zip -r #{sponsor_name}.zip #{sponsor_name}")

      #Renames the folder
      File.rename "#{sponsor_name}.zip",final_filename

      #Asks to upload to AWS, invokes upload_to_aws method
      to_upload = "#{to_path}/#{final_filename}"
      puts "Upload to AWS ? (y/n)"
      i = gets.chomp.downcase

      if i == "y"
        upload_to_aws(final_filename,to_upload)
      end

      #copies the filename to ClipBoard
      IO.popen('pbcopy', 'w') { |f| f << final_filename }
      puts "......................Filename copied to ClipBoard......................"

      puts "Delete Zipped file ? (y/n)"
      i = gets.chomp.downcase
      if i == 'y'
        system ("rm "+ "'" + to_upload + "'")
        puts "File Deleted!"
      end

      puts "\n\n\n"
      Dir.chdir(root)
    end
  end



  def zip_all_sponsors

    root = Dir.pwd
    Dir.mkdir "#{root}/all_zips"

    all_zips_hash = {}

    @sponsors.each do |sponsor|
      Dir.chdir(root)

      #Reads the last folder only ex. 2014-12-20
      chosen_folder = Dir.glob("#{root}/#{sponsor}/*").select{ |f| File.directory? f }.last

      #Zip the Deployable folder inside the last folder
      to_zip = Dir.glob("#{chosen_folder}/Deployable/*").select{ |f| File.directory? f}
      p to_zip


      to_zip.each do |folder_to_zip|
        to_path = File.expand_path("..",folder_to_zip)

        Dir.chdir(to_path)

        sponsor_name = File.basename(folder_to_zip)

        final_filename = "#{Date.today.to_s}-#{sponsor_name}.zip"

        #Zips the folder
        system("zip -r #{sponsor_name}.zip #{sponsor_name}")

        #Renames the folder
        File.rename "#{sponsor_name}.zip",final_filename
        p root
        #Moves the zip to the root all_zips folder
        system("mv #{final_filename} #{root}/all_zips/")
        all_zips_hash["#{final_filename}"] = "#{root}/all_zips/#{final_filename}"
        puts "\n\n\n"
      end
    end

    puts "Upload all these zips to AWS ? (y/n)"
    input = gets.chomp.downcase
    if input == "y"
      zips = Dir.entries("#{root}/all_zips")
      puts zips
      all_zips_hash.each do |filename, file_path|
        # upload_to_aws(filename, file_path)
      end
    end
  end

  def upload_to_aws(filename, to_upload)
    puts "Uploading #{filename} to Amazon S3..."
    sponsor_zip_upload = S3.put_object(
      bucket: "<BUCKET-NAME>",
      key: filename,
      body: File.open(to_upload),
      acl: "public-read"
    )
    puts "Upload Done!"
  end

  def list_sponsors
    @sponsors.each_with_index { |sponsor,index|
      unless sponsor == ""
        if (index % 2 == 0)
          puts "#{index}. #{sponsor}"
        else
          puts "\033[0;33m#{index}. #{sponsor}\033[0m"
        end
      end
    }
    zip_sponsor
  end

  def menu
    system("clear")
    puts "ALL ZIPS UPLOADING TO AMAZON HAS BEEN DISABLED"
    begin
      puts
      loop do
        choose do |menu|
          menu.prompt = "Please select option "
          menu.choice("List Sponsors") { list_sponsors }
          menu.choice("Zip all Sponsors!") { zip_all_sponsors }
          menu.choice(:Quit, "Exit program.") { exit }
        end
      end
    end
  end
end

CreateZip.new
