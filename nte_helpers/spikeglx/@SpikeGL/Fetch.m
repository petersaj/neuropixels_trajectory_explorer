% [daqData,headCt] = Fetch( myObj, js, ip, start_samp, max_samps, channel_subset, downsample_ratio )
%
%     Get MxN matrix of stream data.
%     M = samp_count, MIN(max_samps,available).
%     N = channel count...
%     Data are int16 type.
%     Fetching starts at index start_samp.
%     channel_subset is an optional vector of specific channels to fetch [a,b,c...], or,
%         [-1] = all acquired channels, or,
%         [-2] = all saved channels.
%     downsample_ratio is an integer; return every Nth sample (default = 1).
%     Also returns headCt = index of first sample in matrix.
%
function [mat,headCt] = Fetch( s, js, ip, start_samp, max_samps, varargin )

    if( nargin < 5 )
        error( 'Fetch: Requires at least 5 arguments.' );
    end

    if( ~isnumeric( start_samp ) || ~size( start_samp, 1 ) )
        error( 'Fetch: Invalid samp_start parameter.' );
    end

    if( ~isnumeric( max_samps ) || ~size( max_samps, 1 ) )
        error( 'Fetch: Invalid max_samps parameter.' );
    end

    ChkConn( s );

    % subset has pattern id1#id2#...
    if( nargin >= 6 )
        subset = sprintf( '%d#', varargin{1} );
    else
        subset = '-1#';
    end

    dwnsmp = 1;

    if( nargin >= 7 )

        dwnsmp = varargin{2};

        if( ~isnumeric( dwnsmp ) || length( dwnsmp ) > 1 )
            error( 'Fetch: Downsample factor must be a single numeric value.' );
        end
    end

    ok = CalinsNetMex( 'sendstring', s.handle, ...
            sprintf( 'FETCH %d %d %ld %d %s %d\n', ...
            js, ip, start_samp, max_samps, subset, dwnsmp ) );

    line = CalinsNetMex( 'readline', s.handle );

    if( isempty( line ) )
        error( 'Fetch: Failed - see warning.' );
    end

    % cells       = strsplit( line );
    cells       = strread( line, '%s' );
    mat_dims	= [str2num(cells{2}) str2num(cells{3})];
    headCt      = str2num(cells{4});

    if( ~isnumeric( mat_dims ) || ~size( mat_dims, 2 ) )
        error( 'Fetch: Invalid matrix dimensions.' );
    end

    mat = CalinsNetMex( 'readmatrix', s.handle, 'int16', mat_dims );

    % transpose
    mat = mat';

    ReceiveOK( s, 'FETCH' );
end
