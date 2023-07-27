% params = GetGeomMap( myobj, ip )
%
%     Get geomMap for given logical imec probe.
%     Returned as a struct of name/value pairs.
%     Header fields:
%         head_partNumber   ; string
%         head_numShanks
%         head_shankPitch   ; microns
%         head_shankWidth   ; microns
%     Channel 5, e.g.:
%         ch5_s   ; shank index
%         ch5_x   ; microns from left edge of shank
%         ch5_z   ; microns from center of tip-most electrode row
%         ch5_u   ; used-flag (in CAR operations)
%
function ret = GetGeomMap( s, ip )

    ret = struct();
    res = DoGetCells( s, sprintf( 'GETGEOMMAP %d', ip ) );

      % res is a cell array, each cell containing a string of form
      % '<parameter name> = <parameter value>'
      % Parameter names are sequences of word characters [a-z_A-Z0-9].
      % Parameter values become doubles.

    for i = 1:length( res )

        % (?<xxx>expr) captures token matching expr and names it 'xxx'

        pair = ...
        regexp( res{i}, ...
        '^\s*(?<name>\w+)\s*=\s*(?<value>.*)\s*$', 'names' );

        % pair is a struct array with at most one element. If there
        % is an element, then pair.name is the (string) name, and
        % pair.value is a double value, except for head_partNumber.

        if( ~isempty( pair ) )
            if( i == 1 )
                % partNumber string
                ret.(pair.name) = pair.value;
            else
                ret.(pair.name) = str2num( pair.value );
            end
        end
    end
end
