% [Vmin,Vmax] = GetStreamVoltageRange( myobj, js, ip )
%
%     Returns voltage range of selected data stream.
%
function [Vmin,Vmax] = GetStreamVoltageRange( s, js, ip )

    ret = DoQuery( s, sprintf( 'GETSTREAMVOLTAGERANGE %d %d', js, ip ) );
    C   = textscan( ret, '%f %f' );

    Vmin = C{1};
    Vmax = C{2};
end
