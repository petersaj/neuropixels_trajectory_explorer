% myobj = Opto_emit( myobj, ip, color, site )
%
%     Direct emission to specified site (-1=dark).
%     ip:    imec probe index.
%     color: {0=blue, 1=red}.
%     site:  [0..13], or, -1=dark.
%
function [s] = Opto_emit( s, ip, color, site )

    DoSimpleCmd( s, sprintf( 'OPTOEMIT %d %d %d', ip, color, site ) );
end
