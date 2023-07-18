% mult = GetStreamI16ToVolts( myobj, js, ip, chan )
%
%     Returns multiplier converting 16-bit binary channel to volts.
%
function [ret] = GetStreamI16ToVolts( s, js, ip, chan )

    ret = str2double( DoQuery( s, sprintf( 'GETSTREAMI16TOVOLTS %d %d %d', js, ip, chan ) ) );
end
