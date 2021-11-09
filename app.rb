require 'sinatra'
require 'shellwords'

include Shellwords

set :bind, '0.0.0.0'

def get_enclosures
  `sg_map`.each_line.map do |dev|
    ids = shellsplit(dev)
    ids[0].split('/dev/',2).last unless ids[1] # enclosures dont have a disk id
  end.compact
end

def get_id_tuple(device)
  `lsscsi -g`.each_line.find{|l|l.match device}&.split(' ')&.first.tr('[]','')
end

def clean_split(list, sep, count=0)
  list.split(sep,count).map(&:strip).reject(&:empty?)
end

def get_disk_name_by_sas_address(sas_address)
  raw = sas_address.to_i(16)
  disks = `lsblk -d -o SERIAL,NAME`.lines.map(&:strip)
  sas_id = (0..3).map{|i| (raw + i).to_s(16) }.find do |id|
    match = disks.find {|d| d.match(id) }
    break match.split(' ').last if match
  end
end

def get_enclosure(id)
  all_info = `sg_ses /dev/#{escape id} -p 0xa` #TODO security vuln

  return { info: "No device", sub_enclosures: [] } if all_info.empty?

  main, elements = *all_info.split("additional element status descriptor list")

  {
    info: main,
    sub_enclosures: clean_split(elements, "Element type:").map do |sub_enclosure|
      if sub_enclosure.start_with? "Array device slot"
        header, rest = *clean_split(sub_enclosure, "Element index:",2)
        {
          info: header,
          elements: clean_split(rest, "Element index:").map do |element|
            values = element.lines.map{|l|l.split(',')}.flatten.map(&:strip)
            header = values.shift
            values = Hash[values.map {|v| v.split(':',2).map(&:strip) }]
            {
              info: header,
              values: values.merge(
                "disk" => get_disk_name_by_sas_address(values["SAS address"]))
            }
          end
        }
      else
        nil # todo support other types of subenclosure
      end
    end.compact
  }
end

def get_pretty_enclosures
  result = {}
  get_enclosures.each do |enclosure_name|
    enclosure = get_enclosure(enclosure_name)
    id_tuple = get_id_tuple(enclosure_name)

    result[enclosure_name] = {
      tuple: id_tuple,
      device: enclosure,
      info: enclosure[:info],
      slots: get_pretty_slots(id_tuple, enclosure)
    }
  end
  result
end

def get_slot_path(id_tuple, slot)
  enclosure_path = "/sys/class/enclosure/#{id_tuple}/"
  slot_template = Dir.entries(enclosure_path).filter {|e| e.match("Slot")}.sort.first
  base = slot_template.match(/\d+/)[0].to_i
  slot_id = slot_template.gsub(/\d+/, (slot + base).to_s.rjust(2, '0'))
  "/sys/class/enclosure/#{id_tuple}/#{slot_id}/"
end

def get_pretty_slots(id_tuple, enclosure)
  enclosure[:sub_enclosures].flat_map {|se| se[:elements]}.map do |disk|
    slot = disk[:values]["device slot number"].to_i
    device = disk[:values]["disk"]
    slot_path = get_slot_path(id_tuple, slot)
    slot_info = Hash[Dir.glob(slot_path + '*').filter { |e| File.file? e }.map do |f|
      [f.split('/').last.to_sym, File.read(f) ]
    end]
    {
      slot: slot,
      device: device,
      slot_info: slot_info 
    }
  end
end

def display_list(items, klass=nil)
  %Q{
   <ul class="#{klass}">#{items.map {|i| "<li>#{i}</li>"}.join}</ul>
  }
end

def style
  %Q{
   <style>
     .inline > li {
       display: inline-block;
       padding-right: 2em;
     }
   </style>
  }
end

get '/' do
  style + 
  %Q{
    <h1>#{`hostname`.strip}</h1>
  } +
  display_list(get_pretty_enclosures.map do |name,enclosure|
    %Q{
      <h2>#{enclosure[:info]}</h2>
      <a href="/enclosure/#{name}">#{name}</a>

      #{
        display_list(enclosure[:slots].map do |slot|
          "<h3>#{slot[:slot] + 1}: #{slot[:device]} #{toggle_locate_button(name, slot[:slot])}</h3>" +
            display_list(slot[:slot_info].map do |key, value|
              "#{key}: #{value}"
            end, "inline")
        end)
      }
    }
  end)
end

def toggle_locate_button(enclosure_id, slot)
  %Q{<button onclick="
      fetch('/enclosure/#{enclosure_id}/slot/#{slot}/toggle_locate',
        { method: 'POST' }).then(() => window.location.reload())
     ">Locate</button>}
end

post '/enclosure/:enclosure_id/slot/:slot/toggle_locate' do
  id_tuple = get_id_tuple(params[:enclosure_id])
  slot = params[:slot].to_i.to_s # sanitization
  slot_path = get_slot_path(id_tuple, slot)
  current = File.read(slot_path + "locate").to_i
  puts "Toggle locate current value: #{current}"
  File.write(slot_path + "locate", (current^1).to_s)
  new = File.read(slot_path + "locate").to_i
  puts "Toggle locate new value: #{new}"
end

get '/enclosure/:enclosure_id' do
  enclosure_info = get_enclosure(params['enclosure_id'])

  style +
  %Q{
    <h1>Enclosure</h1>
    <p>#{enclosure_info[:info]}</p>
    <h2>Subenclosures</h2>
    #{
      display_list(enclosure_info[:sub_enclosures].map do |sub_enclosure|
       %Q{
         <h3>#{sub_enclosure[:info]}</h3>
         #{display_list(sub_enclosure[:elements].map do |disk|
           values = disk[:values]
           %Q{
             <h4>Slot #{values["device slot number"]} #{values["disk"]}</h4>
             <!-- #{display_list(disk[:values].map do |key,value|
              "#{key}: #{value}"
             end)} -->
           }
         end
         )}
       }
      end)
    }
  }
end

