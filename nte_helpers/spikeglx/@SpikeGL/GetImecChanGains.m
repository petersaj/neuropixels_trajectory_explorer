% [APgain,LFgain] = GetImecChanGains( myobj, ip, chan )
%
%     Returns the AP and LF gains for given probe and channel.
%
function [APgain,LFgain] = GetImecChanGains( s, ip, chan )

    ret = DoQuery( s, sprintf( 'GETIMECCHANGAINS %d %d', ip, chan ) );
    C   = textscan( ret, '%f %f' );

    APgain = C{1};
    LFgain = C{2};
end
