require "prawn"
require "date"
require 'holidays'
require 'holidays/core_extensions/date'

class Date
  include Holidays::CoreExtensions::Date

  def dayname
    ["Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag"][self.wday]
  end

  def monthname
    ["", "Jannuar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"][self.month]
  end
end

quartal = 3
year = 2017

start_year = Date.new(year, ((quartal - 1) * 3) + 1, 1).cwyear
start_week = Date.new(year, ((quartal - 1) * 3) + 1, 1).cweek

end_year = Date.new(year, quartal * 3, -1).cwyear
end_week = Date.new(year, quartal * 3, -1).cweek

start_date = Date.commercial(start_year, start_week, 1)
end_date = Date.commercial(end_year, end_week, 5)

$lower_part = 40
$upper_part = 50
$padding_row = 12
$number_of_horizontal_lines = 12

def print_month(pdf, date, x, y, highlight_week)
  start_date = Date.new(date.year, date.month, 1)
  end_date = Date.new(date.year, date.month, -1)

  weeks = 1
  week = start_date.cweek
  (start_date..end_date).each do |d|
    if week != d.cweek
      week = d.cweek
      weeks = weeks + 1
    end
  end

  size = 6

  height = 60
  width = pdf.bounds.bottom_right[0]
  month_width = width / 3
  cell_width = month_width / (weeks  + 1)

  translate(width - month_width, y) do
    formatted_text_box [ { text: "#{date.monthname}", styles: [:bold] }
    ], :at => [0, height + 4], :width => month_width, :align => :center, size: size + 1

    ["KW", "MO", "DI", "MI", "DO", "FR", "SA", "SO"].each_with_index do |s, i|
      formatted_text_box [ { text: s, styles: [:bold] }
      ], :at => [0, height - height / 9 * (i + 1)], :width => cell_width, :align => :center, size: size
    end

    x = 1
    week = start_date.cweek
    (start_date..end_date).each do |d|
      if week != d.cweek
        week = d.cweek
        x = x + 1
      end
      y = d.wday
      if y == 0
        y = 7
      end
      y += 1
      if highlight_week.cweek == d.cweek
        pdf.line_width = 0.5
        rounded_rectangle [cell_width * x, height - 5], cell_width, height - 8, 5
        stroke
      end
      formatted_text_box [ { text: d.cweek.to_s }
      ], :at => [cell_width * x, height - height / 9 * 1], :width => cell_width, :align => :center, size: size, styles: :bold
      formatted_text_box [ { text: d.strftime('%d') }
      ], :at => [cell_width * x, height - height / 9 * y], :width => cell_width, :align => :center, size: size
    end
  end
end

def new_page(pdf, start_new_page, page_even, date)
  width = pdf.bounds.bottom_right[0]
  height = pdf.bounds.top_left[1]
  if start_new_page
    pdf.start_new_page
  end
  # pdf.stroke_axis
  pdf.stroke_color '999999'
  pdf.stroke do
    pdf.horizontal_line 0, width, :at => 505
    pdf.horizontal_line 0, width, :at => $lower_part
    (0..(page_even ? 2 : 1)).each do |i|
      (0..$number_of_horizontal_lines).each do |j|
        start_x = i * width / 3
        start_y = $lower_part
        height_y = height - start_y - $upper_part
        pdf.horizontal_line start_x + $padding_row / 2, start_x + (width / 3) - $padding_row, :at => start_y + j * height_y / $number_of_horizontal_lines
      end
    end
  end
  pdf.stroke_color '000000'
  if (page_even)
    text_box "#{date.year.to_s} #{date.monthname}", :at => pdf.bounds.top_left, :width => width, :align => :left, :style => :bold
    text_box "KW #{date.cweek}", :at => [width - width / 3, height], :width => width / 3, :align => :right
    text_box "Hightlight der Woche", :at => [10, $lower_part - 5], :width => width / 3, :align => :left, size: 8
  else
    text_box "#{(date).monthname} #{(date).year.to_s}", :at => pdf.bounds.top_left, :width => width, :align => :right, :style => :bold
    text_box "Notizen", :at => [width - width / 3 - 10, 500], :width => width / 3, :align => :right, size: 8
    text_box "Sonstige Aufgaben", :at => [width - width / 3 - 10, $lower_part - 5], :width => width / 3, :align => :right, size: 8
    text_box "Ziel der Woche", :at => [width - width / 3 - 10, 260], :width => width / 3, :align => :right, size: 8

    print_month(pdf, date, 0, 120, date)
    print_month(pdf, date >> 1, 0, 50, date)
  end
end

Prawn::Document.generate("calender.pdf", page_layout: :portrait, page_size: "A5") do
  font_families.update("Roboto" => {
    :normal => 'fonts/Roboto-Regular.ttf',
    :bold => 'fonts/Roboto-Bold.ttf',
    :italic => 'fonts/Roboto-Italic.ttf'
  })
  font "Roboto"
  font_size 12
  width = bounds.bottom_right[0]
  height = bounds.top_left[1]

  new_page(self, false, true, start_date)

  page = 0
  num = 0
  next_page = false

  todos = Hash.new {|h,k| h[k] = [] }
  current_month = start_date.month
  current_week = start_date.cweek - 1
  last_date = nil
  ((start_date - 7)..(end_date + 7)).each do |date|
    if [0, 6].include?(date.wday)
      next
    end
    if date.holiday?(:de_he)
      next
    end

    todos[date] << "Stundenzettel"
    if current_month != date.month
      todos[date] << "Monatsbericht"
    end

    if current_week != date.cweek
      todos[date] << "Wochenplanung"
      current_week = date.cweek
    end

    if current_month != date.month
      todos[last_date] << "RPME"
      todos[date] << "Monatsplanung"
      if date.month % 3 == 1
        todos[date] << "Quartalsplanung"
      end
      current_month = date.month
    end

    last_date = date
  end

  dates = (start_date..end_date).to_a
  if dates.length > 7
    dates.insert(10, *((start_date - 4)...start_date))
  end
  number_of_dates = 14 - (dates.length % 14)
  dates = dates + ((end_date + 1)..(end_date + number_of_dates)).to_a

  reorder_dates = dates[0..13]
  dates[14..-1].each_slice(14) do |slice|
    reorder_dates = reorder_dates + slice[4..-1]
    reorder_dates = reorder_dates + slice[0..3]
  end

  reorder_dates.each do |date|
    if [0, 6].include?(date.wday)
      next
    end
    if num % 5 == (page % 2 == 0 ? 3 : 2)
      page = page + 1
      num = 0
      new_page(self, true, page % 2 == 0, date)
    end

    translate(num * width / 3, 465) do
      feiertag = ""
      if date.holiday?(:de_he)
        feiertag = " Feiertag"
      end
      formatted_text_box [ { text: "#{date.strftime'%d'}", styles: [:bold] },
                           { text: " #{date.dayname}", size: 8 },
                           { text: feiertag, size: 6, styles: [:italic] }
      ], :at => [6, 30], :width => width / 3, :align => :left
    end

    if todos[date]
      todos[date].each_with_index do |todo, i|
        start_y = $lower_part
        height_y = height - start_y - $upper_part
        translate(num * width / 3 + 20, start_y + i * height_y / $number_of_horizontal_lines - 6 ) do
          stroke_circle [0, 24], 3
          formatted_text_box [ { text: todo },
          ], :at => [6, 30], :width => width / 3, :align => :left, :size => 10
        end
      end
    end

    num = num + 1
  end
end