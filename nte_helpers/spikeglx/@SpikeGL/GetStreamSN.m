% [SN,type] = GetStreamSN( myobj, js, ip )
%
%     js = 1: Return OneBox SN and slot.
%     js = 2: Return probe  SN and type.
%     SN = serial number string.
%
function [SN,type] = GetStreamSN( s, js, ip )

    ret = DoQuery( s, sprintf( 'GETSTREAMSN %d %d', js, ip ) );
    C   = textscan( ret, '%[^ ] %d' );

    SN   = C{1};
    type = C{2};
end
