# 
# A collection of custom matchers for Arrow specifications
# $Id$
# 

module TimeMatchers
    class BeAfter
        def initialize( expected )
            @expected = expected
        end

        def matches?( actual )
            @actual = actual
            @actual > @expected
        end

        def failure_message
            "expected #{@actual} to be after #{@expected}"
        end

        def negative_failure_message
            "expected #{@actual} not to be after #{@expected}"
        end
    end

    def be_after( expected )
        BeAfter.new( expected )
    end
end
