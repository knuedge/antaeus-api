# Query parameter parser
def parse_complex_query(q, defaults = {})
  p = {}
  q.each do |query|
    key, value = query.split ':'
    parsed_value = value
    parsed_value = value.split(',') if value.match(/,/)
    if value.match(/\.\./)
      times = value.split('..').map { |t| Date.parse(t) }
      parsed_value = (times[0]..times[1])
    end
    p[key.to_sym] = p.key?(key.to_sym) ? [*p[key.to_sym], parsed_value] : parsed_value
  end
  # return the defaults + new stuff
  defaults.merge p
end
