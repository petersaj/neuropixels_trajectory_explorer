% maxInt = GetStreamMaxInt( myobj, js, ip )
%
%     Returns largest positive integer value for selected stream.
%
function [ret] = GetStreamMaxInt( s, js, ip )

    ret = sscanf( DoQuery( s, sprintf( 'GETSTREAMMAXINT %d %d', js, ip ) ), '%d' );
end
