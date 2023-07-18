% n_substreams = GetStreamNP( myobj, js )
%
%     Returns number (np) of js-type substreams.
%     For the given js, ip has range [0..np-1].
%
function [ret] = GetStreamNP( s, js )

    ret = sscanf( DoQuery( s, sprintf( 'GETSTREAMNP %d', js ) ), '%d' );
end
