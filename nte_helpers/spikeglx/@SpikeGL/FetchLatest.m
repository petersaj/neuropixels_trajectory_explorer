% [daqData,headCt] = FetchLatest( myObj, js, ip, max_samps, channel_subset, downsample_ratio )
%
%     Get MxN matrix of the most recent stream data.
%     M = samp_count, MIN(max_samps,available).
%     N = channel count...
%     Data are int16 type.
%     channel_subset is an optional vector of specific channels to fetch [a,b,c...], or,
%         [-1] = all acquired channels, or,
%         [-2] = all saved channels.
%     downsample_ratio is an integer; return every Nth sample (default = 1).
%     Also returns headCt = index of first sample in matrix.
%
function [mat,headCt] = FetchLatest( s, js, ip, max_samps, varargin )

    if( nargin < 4 )
        error( 'FetchLatest: Requires at least four arguments.' );
    else if( nargin >= 5 )
        subset = varargin{1};
    else
        subset = [-1];
    end

    dwnsmp = 1;

    if( nargin >= 6 )

        dwnsmp = varargin{2};

        if( ~isnumeric( dwnsmp ) || length( dwnsmp ) > 1 )
            error( 'FetchLatest: Downsample factor must be a single numeric value.' );
        end
    end

    max_ct = GetStreamSampleCount( s, js, ip );

    if( max_samps > max_ct )
        max_samps = max_ct;
    end

    [mat,headCt] = Fetch( s, js, ip, max_ct - max_samps, max_samps, subset, dwnsmp );
end
