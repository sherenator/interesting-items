
# Original version courtesy of: https://github.com/jsvd/logstash-filter-ruby-scripts/blob/master/scripts/jsonarray.rb
# Used to parse gitlab api_json data as shown below
# "params":[{"key":"project","value":"cci-monster/CCI.Monster"},{"key":"check_ip","value":"192.168.2.13"}]
# Debug logging and corellation IDs facilitated via 'logger' and 'securerandom'

require 'logger'
require 'securerandom'

def register(params)
   @sourceField = params["sourceField"]
   @nameField = params["nameField"]
   @valueField = params["valueField"]
   @dest = params["dest"]
   logger.info("The filter registration params are:", "value" => params)
end

def filter(event)
  uuid = SecureRandom.uuid
  
  if event.get(@sourceField).nil?
    logger.info("#{uuid} - event.get(@sourceField) is nil:", "value" => event.get(@sourceField))
    event.tag("#{@sourceField}_not_found")
    return [event]
  end
  object = event.get(@sourceField)
  logger.info("#{uuid} - The event specific params are:", "value" => object)
  h = {}
  for thing in object
    if thing[@nameField].nil?
	  logger.info("#{uuid} - event.get(@nameField) is nil:", "value" => event.get(@nameField))
      event.tag("#{@nameField}_not_found")
      return [event]
    end
    itemName = thing[@nameField]
    if thing[@valueField].nil?
	  logger.info("#{uuid} - event.get(@valueField) is nil:", "value" => event.get(@valueField))
      event.tag("#{@valueField}_not_found")
      return [event]
    end
    itemValue = thing[@valueField]
    h[itemName] = itemValue
  end
  event.set(@dest, h)
  logger.info("#{uuid} - FINAL EVENT DATA:", "value" => object)
  return [event]
end
