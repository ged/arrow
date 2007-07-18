#!/usr/bin/env ruby

class ConstantDumper
    def self::handler( req )
        req.content_type = "text/plain"
    
        map = ["# Apache constants"]
        Apache.constants.sort.each do |const|
            val = Apache.const_get( const )
            next unless val.is_a?( Numeric ) || val.is_a?( String )
            map << "Apache::%s = %p" % [const, val]
        end

        req.send_http_header
        req.puts( map )

        return Apache::OK
    end

end


