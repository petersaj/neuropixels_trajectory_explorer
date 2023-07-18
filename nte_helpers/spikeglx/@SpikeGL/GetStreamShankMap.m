% [nS,nC,nR,mat] = GetStreamShankMap( myObj, js, ip )
%
%     Get shank map for NI stream (js = 0):
%     {nS,nC,nR} = max {shanks, cols, rows} on this probe;
%     mat = Mx4 matrix of shank map entries, where,
%     M   = channel count.
%     4   = given channel's zero-based {shank, col, row} indices,
%         plus a 'used' flag which is 1 if the channel should be
%         included in displays and spatial averaging operations.
%     Data are int16 type.
%
function [nS,nC,nR,mat] = GetStreamShankMap( s, js, ip )

    ChkConn( s );

    ok = CalinsNetMex( 'sendstring', s.handle, ...
            sprintf( 'GETSTREAMSHANKMAP %d %d\n', js, ip ) );

    line = CalinsNetMex( 'readline', s.handle );

    if( isempty( line ) )
        error( 'GetStreamShankMap: Failed - see warning.' );
    end

    cells = strread( line, '%s' );
    nS    = str2num(cells{2});
    nC    = str2num(cells{3});
    nR    = str2num(cells{4});
    dims  = [4 str2num(cells{5})];

    mat = CalinsNetMex( 'readmatrix', s.handle, 'int16', dims );

    % transpose
    mat = mat';

    ReceiveOK( s, 'GETSTREAMSHANKMAP' );
end
