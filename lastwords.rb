# this ruby (2.4.2) script set out 
# to scrape and organize data from https://www.tdcj.state.tx.us/death_row/dr_executed_offenders.html and its links
# sort out errors from abnormal data pages such as https://www.tdcj.state.tx.us/death_row/dr_info/lealhumberto.jpg
# and write offender information onto a json file (and also to terminal)

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'pry'
require 'json'
require 'date'

class Offender
	attr_reader :exe_num, :lastname, :firstname, :tdcj_num, :race, :gender, :age, :image, :rec_date, :exe_date, :lastwords, :notes
	def initialize(exe_num, lastname, firstname, tdcj_num, race, gender, age, image, rec_date, exe_date, lastwords, notes)
		@exe_num = exe_num
		@lastname = lastname
		@firstname = firstname
		@tdcj_num = tdcj_num
		@race = race
		@gender = gender
		@age = age
		@image = image
		@rec_date = rec_date
		@exe_date = exe_date
		@lastwords = lastwords
		@notes = notes
	end
	def to_hash
		{
			exe_num: @exe_num,
			lastname: @lastname,
			firstname: @firstname,
			tdcj_num: @tdcj_num,
			race: @race, 
			gender: @gender,
			age: @age,
			image: @image,
			rec_date: @rec_date,
			exe_date: @exe_date,
			lastwords: @lastwords,
			notes: @notes
		}
	end
	def to_json
	   to_hash.to_json
	end
end
page = Nokogiri::HTML(open("https://www.tdcj.state.tx.us/death_row/dr_executed_offenders.html"))   
all_links = page.css("tr a")
all_half_links = all_links.map { |link| link["href"] }
offender_info_links = all_half_links.values_at(* all_half_links.each_index.select {|i| i.even?})
lastwords_links = all_half_links.values_at(* all_half_links.each_index.select {|i| i.odd?})
total_num = lastwords_links.length
all_details = Array.new

for j in 0..(total_num - 1) do
	current_entry = "table.tdcj_table.indent :nth-child(" + (j + 3).to_s + ") "
	exe_num = page.css(current_entry + ":nth-child(1)")[0].text
	lastname = page.css(current_entry + ":nth-child(4)").text
	firstname = page.css(current_entry + ":nth-child(5)").text
	tdcj_num = page.css(current_entry + ":nth-child(6)").text
	age = page.css(current_entry + ":nth-child(7)").text
	exe_date = page.css(current_entry + ":nth-child(8)").text
	race = page.css(current_entry + ":nth-child(9)").text
	county = page.css(current_entry + ":nth-child(10)").text
	# get to infopage
	begin
		if offender_info_links[j].start_with?("/death_row/")
			offender_info_link = offender_info_links[j][11..-1]
		else 
			offender_info_link = offender_info_links[j]
		end
		offender_page = Nokogiri::HTML(open("https://www.tdcj.state.tx.us/death_row/" + offender_info_link))
		if offender_info_link.end_with?("jpg")
			gender = "N.A."
			img_src = "N.A."
			image = "N.A."
			rec_date = "N.A."
			notes = "More details on this image: https://www.tdcj.state.tx.us/death_row/" + offender_info_link
		else
			if offender_page.at('td:contains("Gender") + td').nil?
				gender = "N.A."
			else
				gender = offender_page.at('td:contains("Gender") + td').text.strip
			end
			if offender_page.at('td:contains("Date Received") + td').nil?
				rec_date = "N.A."
			else
				rec_date = offender_page.at('td:contains("Date Received") + td').text.strip
			end 
			if offender_page.css("img.photo_border_black_right")[0].nil?
				img_src = "N.A."
				image = "N.A."
			else
				img_src = offender_page.css("img.photo_border_black_right")[0].attributes["src"].value
				image = "https://www.tdcj.state.tx.us/death_row/dr_info/" + offender_page.css("img.photo_border_black_right")[0].attributes["src"].value
			end
			notes = "N.A."
		end
	rescue OpenURI::HTTPError => e
		if e.message == "404 Not Found"
			puts "Encountered 404 Error at index " + j + " with the following link: https://www.tdcj.state.tx.us/death_row/" + offender_info_link
			binding.pry
		else
			raise e
		end
	end
	# get to detail page
	begin
		if lastwords_links[j].start_with?("/death_row/")
			lastwords_link = lastwords_links[j][11..-1]
		else
			lastwords_link = lastwords_links[j]
		end
		lastwords_page = Nokogiri::HTML(open("https://www.tdcj.state.tx.us/death_row/" + lastwords_link))
		num_paragraph = lastwords_page.css("div#content_right :nth-child(n+10)").length
		lastwords = ""
		for i in 0..(num_paragraph - 1) do
			new_paragraph = lastwords_page.css("div#content_right :nth-child(n+10)")[i].text + " "
			lastwords << new_paragraph
		end
		lastwords = lastwords.gsub("  ", " ").lstrip.rstrip
	rescue OpenURI::HTTPError => e
		if e.message == "404 Not Found"
			puts "Encountered 404 Error at index " + j + " with the following link: https://www.tdcj.state.tx.us/death_row/" + lastwords_link
		else
			raise e
		end
	end
	all_details.push(Offender.new(exe_num, lastname, firstname, tdcj_num, race, gender, age, image, rec_date, exe_date, lastwords, notes).to_hash)
	# write to file
	File.open("./offenders.json", "w") do |f|
		f.puts all_details
	end 
end
# puts organized json to terminal
puts JSON.pretty_generate(all_details)