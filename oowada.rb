# coding: utf-8
require 'tapp'
require 'mechanize'
require 'date'
require 'optparse'

OPT = {}
opt = OptionParser.new
opt.on('-d date', '指定した日付以降を調べる') { |v| OPT[:date] = v }
opt.on('-a', '夜間が空いて無い分も表示する') { |v| OPT[:all] = v }
opt.parse!(ARGV)

DATE = OPT[:date] ? Date.parse(OPT[:date]) : nil
ALL = OPT[:all]


END_OF_MONTH = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
ROOMS = {'学習室4' => 2, '学習室2' => 1, '学習室7' => 4, '学習室6' => 3, '学習室1' => 0}

def remaining_days(date, tomorrow)
	end_month = end_month(tomorrow)
	end_of_month = end_of_month(end_month)
	end_day = Date.new(end_month.year, end_month.month, end_of_month)
	
	(end_day - date).to_i
end

def end_month(date)
	scope_month = 20 <= date.day ? 3 : 2
	date.next_month(scope_month)
end

def end_of_month(month)
	END_OF_MONTH[month.month - 1]
end

def formatter(html)
	doc = Nokogiri::HTML(html)
	doc.css('table tbody tr').map do |node|
		day = node.css('th strong').children.first.text
		states = node.css('td').map { |n| n.children.first['alt'] || 'O' }
		"#{day}#{states.join(':')}" if ALL || states.last == 'O'
	end.compact
end

puts now = DateTime.now
tomorrow = now.to_date + 1 

prefix = DATE && "#{DATE}_"
file = File.open(now.strftime("#{prefix}%Y%m%d_%H%M.txt"), 'w')
file.puts now

agent = Mechanize.new
agent.verify_mode = OpenSSL::SSL::VERIFY_NONE

page = agent.get('https://yoyaku.cultos-y.jp/shibuya-web/reserve/gin_menu')

puts 'top menu'
form = page.form_with(name: 'RiyosyaForm')
btn = form.buttons[0]
page = form.click_button(btn)

puts 'system top'
form = page.form_with(action: '/shibuya-web/reserve/gin_z_group_sel_1')
btn = form.buttons[0]
page = form.click_button(btn)

puts 'select type'
form = page.form_with(name: 'selectBunriForm')
form.field_with(name: 'g_bunruicd').options[9].select
form.field_with(name: 'bunruicd').options[9].select
page = form.submit

puts 'select use'
page = page.form_with(name: 'formname') do |form|
	form.field_with(name: 'riyosmk').value = '1020'
end.submit

puts 'select facility'
page = page.form_with(name: 'basyoForm') do |form|
	form.field_with(name: 'g_basyocd').options[0].select
	form.field_with(name: 'g_jitubasyocd').options[0].select
	form.field_with(name: 'shisetugroup').options[0].select
	form.field_with(name: 'g_systemcd').options[0].select
	form.field_with(name: 'g_mkkbn').options[0].select
end.submit

ROOMS.each do |name, room|
	date = DATE || tomorrow
	file.puts "■ #{name}"
	puts "■ #{name}"

	page = page.form_with(name: 'form_nm') do |form|
		form.field_with(name: 'g_kinomkkbn').options[room].select
		form.field_with(name: 'g_basyocd').options[room].select
		form.field_with(name: 'g_stgroup').options[room].select
		form.field_with(name: 'g_sisetucd').options[room].select
	end.submit

	page = page.form_with(name: 'Ok') do |form|
		form.action = '/shibuya-web/reserve/gin_z_datetime_sel_1'
		form.field_with(name: 'ymd').value = date.strftime('%Y%m%d')
	end.submit

	page.encoding = 'utf-8'
	page = page.form_with(name: 'form_nm') do |form|
		form.action = '/shibuya-web/reserve/gin_z_amenitytime_sel_1'
		form.field_with(name: 'showStartKoma').value = '1'
		form.field_with(name: 'showEndKoma').value = '7'
	end.submit

	puts formatter(agent.page.body)

	days = remaining_days(date, tomorrow)
	(days / 7).times do
		date += 7
		page.encoding = 'utf-8'
		page = page.form_with(name: 'chgDspDateFrm') do |form|
			form.action = '/shibuya-web/reserve/gin_z_amenitytime_sel_1'
			form.field_with(name: 'u_genzai_idx').value = '6'
			form.field_with(name: 'flg_ikou').value = '1'
			form.field_with(name: 'hiduke_sousa_flg').value = '0'
			form.field_with(name: 'u_hyojibi').value = date.strftime('%Y%m%d')
			form.field_with(name: 'showStartKoma').value = '1'
			form.field_with(name: 'showEndKoma').value = '7'
		end.submit
		
		file.puts formatter(agent.page.body)
		puts formatter(agent.page.body)
	end

	page = page.link_with(text: '部屋選択（予約）').click
end

file.close
#puts page.body.encode('CP932', 'UTF-8')
